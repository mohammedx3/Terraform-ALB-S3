package test

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	// "encoding/json"
	"log"
	// "os"
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

// An example of how to test the Terraform module in examples/terraform-redeploy-example using Terratest. We deploy the
// Terraform code, check that the load balancer returns the expected response, redeploy the code, and check that the
// entire time during the redeploy, the load balancer continues returning a valid response and never returns an error
// (i.e., we validate that zero-downtime deployment works).
//
// The test is broken into "stages" so you can skip stages by setting environment variables (e.g., skip stage
// "deploy_initial" by setting the environment variable "SKIP_deploy_initial=true"), which speeds up iteration when
// running this test over and over again locally.
func TestTerraformRedeployExample(t *testing.T) {
	t.Parallel()

	// The folder where we have our Terraform code
	workingDir := "../"

	// At the end of the test, clean up all the resources we created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	test_structure.RunTestStage(t, "pick_region", func() {
		awsRegion := "eu-west-1"
		// Save the region, so that we reuse the same region when we skip stages
		test_structure.SaveString(t, workingDir, "region", awsRegion)
	})

	// Deploy the web app
	test_structure.RunTestStage(t, "deploy_initial", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		initialDeploy(t, awsRegion, workingDir)
	})

	// Validate that the ASG deployed and is responding to HTTP requests
	test_structure.RunTestStage(t, "validate_initial", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		validateAsgRunningWebServer(t, awsRegion, workingDir)
	})

}

// Do the initial deployment of the terraform-redeploy-example
func initialDeploy(t *testing.T, awsRegion string, workingDir string) {
	// A unique ID we can use to namespace resources so we don't clash with anything already in the AWS account or
	// tests running in parallel
	uniqueID := random.UniqueId()

	// Give the VPC and the subnets correct CIDRs
	vpcCidr := "10.0.0.0/16"
	publicSubnetCidr1 := "10.0.0.0/24"
	publicSubnetCidr2 := "10.0.1.0/24"

	keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, workingDir, keyPair)

	// Give the ASG and other resources in the Terraform code a name with a unique ID so it doesn't clash
	// with anything else in the AWS account.
	name := fmt.Sprintf("terraTest-%s", uniqueID)

	// Some AWS regions are missing certain instance types, so pick an available type based on the region we picked
	instanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.xlarge"})

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: workingDir,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"aws_region":         awsRegion,
			"instance_name":      name,
			"instance_type":      instanceType,
			"key_pair_name":      keyPair.Name,
			"bucket_name":        fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
			"main_vpc_cidr":      vpcCidr,
			"first_subnet_cidr":  publicSubnetCidr1,
			"second_subnet_cidr": publicSubnetCidr2,
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

	// Assert files were uploaded by checking returned content is not null and of type strings
	assert.NotEqual(t, nil, actualBucketObject1Content)
	assert.IsType(t, "", actualBucketObject1Content)
	assert.NotEqual(t, nil, actualBucketObject2Content)
	assert.IsType(t, "", actualBucketObject2Content)

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	// The path to where our Terraform code is located
	// Run `terraform output` to get the value of an output variable
	publicSubnetId1 := terraform.Output(t, terraformOptions, "public1_subnet_id")
	publicSubnetId2 := terraform.Output(t, terraformOptions, "public2_subnet_id")
	vpcId := terraform.Output(t, terraformOptions, "main_vpc_id")

	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)

	require.Equal(t, 2, len(subnets))
	// Verify if the network that is supposed to be public is really public
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId1, awsRegion))
	// Verify if the network that is supposed to be public is really public
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId2, awsRegion))

}

const file1 = "/home/ubuntu/file1_access.txt"
const file2 = "/home/ubuntu/file2_access.txt"

// This size is configured in the terraform-redeploy-example itself
const asgSize = 2

// Default location where the User Data script generates a presign url for the files.
func retryToGetFiles(t *testing.T, awsRegion string, keyPair *aws.Ec2Keypair, asgName string, file1 string, file2 string) (map[string]map[string]string, error) {
	fileContentsMaxTries := 30
	fileContentSleepTime := 60 * time.Second

	for i := 0; i < fileContentsMaxTries; i++ {
		logger.Logf(t, "[%d] Trying to get files contents", i)
		instanceIdToFilePathToContents, filesContentsError := aws.FetchContentsOfFilesFromAsgE(t, awsRegion, "ubuntu", keyPair, asgName, true, file1, file2)

		if filesContentsError == nil {
			return instanceIdToFilePathToContents, nil
		}

		logger.Logf(t, "[%d] Failed to get the files", i)
		time.Sleep(fileContentSleepTime)
	}

	return nil, errors.New("Failed to get files contents")
}

// Validate the ASG has been deployed and is working
func validateAsgRunningWebServer(t *testing.T, awsRegion string, workingDir string) {
	// Load the Terraform Options saved by the earlier deploy_terraform stage
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)

	keyPair := test_structure.LoadEc2KeyPair(t, workingDir)

	// Run `terraform output` to get the value of an output variable
	lb_url := terraform.Output(t, terraformOptions, "url")

	asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")

	instanceIdToFilePathToContents, filesContentsError := retryToGetFiles(t, awsRegion, keyPair, asgName, file1, file2)

	if filesContentsError != nil {
		logger.Logf(t, "Error while getting file contents: %s", filesContentsError.Error())
	}

	// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
	tlsConfig := tls.Config{}

	if filesContentsError == nil {
		require.Len(t, instanceIdToFilePathToContents, asgSize)
	}

	// Wait and verify the ASG is scaled to the desired capacity. It can take a few minutes for the ASG to boot up, so
	// retry a few times.
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	aws.WaitForCapacity(t, asgName, awsRegion, maxRetries, timeBetweenRetries)
	capacityInfo := aws.GetCapacityInfoForAsg(t, asgName, awsRegion)
	assert.Equal(t, capacityInfo.DesiredCapacity, int64(2))
	assert.Equal(t, capacityInfo.CurrentCapacity, int64(2))

	// Figure out what text the ASG should return for each request

	expectedText := terraform.Output(t, terraformOptions, "time_stamp")

	if filesContentsError == nil {
		lb_parsed_url, _ := url.Parse(strings.TrimSpace(lb_url))
		for _, filePathToContents := range instanceIdToFilePathToContents {
			fileContent := strings.TrimSpace(filePathToContents[file1])

			fileContent2 := strings.TrimSpace(filePathToContents[file2])

			fullURL1 := BuildLbUrl(fileContent, lb_parsed_url)

			fullURL2 := BuildLbUrl(fileContent2, lb_parsed_url)

			http_helper.HttpGetWithRetry(t, fullURL1, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
			http_helper.HttpGetWithRetry(t, fullURL2, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
		}
	}
}

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
