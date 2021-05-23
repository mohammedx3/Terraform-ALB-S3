package test

// Needed modules to our code.
import (
	"errors"
	"fmt"
	"strings"
	"testing"
	"github.com/stretchr/testify/require"
	"log"
	"crypto/tls"
	"net/url"
	"time"
	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

// The test is broken into two stagas:
// 1. Deploy the infrastructure
//   1. Check that everything was created successfully.
//   2. Check that the VPC is publicly accessiable.
//   3. Check that the files exists in the S3 bucket.

// 2. Check that the load balancer URL returns status of 200 when trying to access both files.

func TestTerraformDeployExample(t *testing.T) {
	// tests running in parallel
	t.Parallel()

	// The folder where we have our Terraform code
	workingDir := "../"

	// At the end of the test, clean up all the resources we created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	// The region AWS will perform all its deployment.
	test_structure.RunTestStage(t, "pick_region", func() {
		awsRegion := "eu-west-1"
		// Save the region, so that we reuse the same region when we skip stages
		test_structure.SaveString(t, workingDir, "region", awsRegion)
	})

	// Deploy the web app.
	test_structure.RunTestStage(t, "deploy_initial", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		initialDeploy(t, awsRegion, workingDir)
	})

	// Validate that the load balancer is deployed and is responding to HTTP requests
	test_structure.RunTestStage(t, "validate_initial", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		validateAsgRunningWebServer(t, awsRegion, workingDir)
	})

}

// Do the initial deployment of the terraform configs.
func initialDeploy(t *testing.T, awsRegion string, workingDir string) {
	// A unique ID we can use to namespace resources so we don't clash with anything already in the AWS account or
	uniqueID := strings.ToLower(random.UniqueId())

	// Give the VPC and the subnets correct CIDRs
	vpcCidr := "10.0.0.0/16"
	publicSubnetCidr1 := "10.0.0.0/24"
	publicSubnetCidr2 := "10.0.1.0/24"

	// Create the keypair it will be used to fetch the URL from the files and to be able to SSH into the machine
	// In case the tst fails.
	keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, workingDir, keyPair)

	// Give the ASG and other resources in the Terraform code a name with a unique ID so it doesn't clash
	// with anything else in the AWS account.
	name := fmt.Sprintf("terra-test-%s", uniqueID)

	// For testing purpose, I have set the instance type to t2.xlarge to be able to execute the bash commands Quickly
	// Install the packages and return the file URL.
	instanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.xlarge"})

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: workingDir,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"aws_region":         awsRegion,
			"instance_type":      instanceType,
			"key_pair_name":      keyPair.Name,
			"main_vpc_cidr":      vpcCidr,
			"first_subnet_cidr":  publicSubnetCidr1,
			"second_subnet_cidr": publicSubnetCidr2,
			"profile_name":		  name,
			"iam_name":			  name,
	     	"iam_policy_name":    name,
			"iam_policy_attach":  name,
			"bucket_name":        name,
			"instance_name":      name,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// Save the Terraform Options struct so future test stages can use it
	test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Get the bucket ID so we can query AWS
	bucketID := terraform.Output(t, terraformOptions, "bucket_id")

	// Test that the bucket exists.
	actualBucketStatus := aws.AssertS3BucketExistsE(t, awsRegion, bucketID)
	assert.Equal(t, nil, actualBucketStatus)

	// Test there is 2 files with names "file1.txt" and "file2.txt"
	actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "test1.txt")
	actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "testt2.txt")

	// Assert files were uploaded by checking returned content is not null and of type strings.
	assert.NotEqual(t, nil, actualBucketObject1Content)
	assert.IsType(t, "", actualBucketObject1Content)
	assert.NotEqual(t, nil, actualBucketObject2Content)
	assert.IsType(t, "", actualBucketObject2Content)

	// Catch the output of subnet id from terraform and apply tests.
	publicSubnetId1 := terraform.Output(t, terraformOptions, "public1_subnet_id")
	publicSubnetId2 := terraform.Output(t, terraformOptions, "public2_subnet_id")
	vpcId := terraform.Output(t, terraformOptions, "main_vpc_id")

	// Verify that the subnets both exist in the VPC.
	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)
	require.Equal(t, 2, len(subnets))

	// Verify that the network is really public.
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId1, awsRegion))
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId2, awsRegion))

}

// Path to where our files exist in the machines.
// The files has the presigned URL of the s3 bucket inside the files.
const file1 = "/home/ubuntu/file1_access.txt"
const file2 = "/home/ubuntu/file2_access.txt"

// The size of the ASG.
const asgSize = 2

// Because the files might be not ready yet for the check, we will retry for maxmium of 30 times each has 1 minute sleep time.
func retryToGetFiles(t *testing.T, awsRegion string, keyPair *aws.Ec2Keypair, asgName string, file1 string, file2 string) (map[string]map[string]string, error) {
	fileContentsMaxTries := 30
	fileContentSleepTime := 60 * time.Second
	// We created a for loop to keep checking on the contents of the file till it works or 30 minutes have passed.
	for i := 0; i < fileContentsMaxTries; i++ {
		logger.Logf(t, "[%d] Trying to get files contents, it might take a while", i)
		// instanceIdToFilePathToContents will return 2 values, we only need the file content to pass it to the http checker.
		instanceIdToFilePathToContents, filesContentsError := aws.FetchContentsOfFilesFromAsgE(t, awsRegion, "ubuntu", keyPair, asgName, true, file1, file2)

		if filesContentsError == nil {
			return instanceIdToFilePathToContents, nil
		}

		logger.Logf(t, "[%d] Failed to get the files, Retrying again in 1 minute ....", i)
		time.Sleep(fileContentSleepTime)
	}

	return nil, errors.New("Failed to get files contents")
}

// Validate the ASG has been deployed and is working
func validateAsgRunningWebServer(t *testing.T, awsRegion string, workingDir string) {
	// Load the Terraform Options saved by the earlier deploy_terraform stage
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	// Load the key pair to be able to SSH into the machines.
	keyPair := test_structure.LoadEc2KeyPair(t, workingDir)

	// Fetch the URL and the autoscalling group name outputs from Terraform.
	lb_url := terraform.Output(t, terraformOptions, "url")
	asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")

	// SSH into the machines and get the content of the files and return them.
	instanceIdToFilePathToContents, filesContentsError := retryToGetFiles(t, awsRegion, keyPair, asgName, file1, file2)

	if filesContentsError != nil {
		logger.Logf(t, "Error while getting file contents: %s", filesContentsError.Error())
	}
	
	if filesContentsError == nil {
		require.Len(t, instanceIdToFilePathToContents, asgSize)
	}

	// Setup a TLS configuration to submit with the helper.
	tlsConfig := tls.Config{}


	// Wait and verify the ASG is scaled to the desired capacity. It can take a few minutes for the ASG to boot up, so
	// retry a few times.
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	aws.WaitForCapacity(t, asgName, awsRegion, maxRetries, timeBetweenRetries)
	capacityInfo := aws.GetCapacityInfoForAsg(t, asgName, awsRegion)
	assert.Equal(t, capacityInfo.DesiredCapacity, int64(2))
	assert.Equal(t, capacityInfo.CurrentCapacity, int64(2))

	// Capture the output of the time stamp from Terraform to check that its written in the files of the s3.
	expectedText := terraform.Output(t, terraformOptions, "time_stamp")

	// Once we captured the content of the files (which is the presigned URL to the s3)
	// we need to trim the hostname of the URL (which is the bucket url) which is also https
	// Then replace it with the hostname of the loadbalancer (because its http)
	// So the final result would be the load balancer hostname + the file + the s3 access
	if filesContentsError == nil {
		lb_parsed_url, _ := url.Parse(strings.TrimSpace(lb_url))
		for _, filePathToContents := range instanceIdToFilePathToContents {
			fileContent := strings.TrimSpace(filePathToContents[file1])
			fileContent2 := strings.TrimSpace(filePathToContents[file2])
			fullURL1 := BuildLbUrl(fileContent, lb_parsed_url)
			fullURL2 := BuildLbUrl(fileContent2, lb_parsed_url)

			// Check the final URL, read the file, if the file has the time stamp in it then it will return 200 and the test is passed.
			http_helper.HttpGetWithRetry(t, fullURL1, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
			http_helper.HttpGetWithRetry(t, fullURL2, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
		}
	}
}

// The functions that takes both urls and rebuild them into one working url that will be the load balancer's.
func BuildLbUrl(file_url string, lb_url *url.URL) string {
	file_url_parsed, e := url.Parse(file_url)

	if e != nil {
		log.Fatal(e)
	}

	fmt.Println(lb_url.Host)

	file_url_parsed.Host = lb_url.Host
	file_url_parsed.Scheme = lb_url.Scheme

	return file_url_parsed.String()
}
