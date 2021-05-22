package test

import (
	"github.com/stretchr/testify/require"
	"fmt"
	"strings"
	"testing"
	// "encoding/json"
	"log"
	// "os"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"crypto/tls"
	"time"
	"net/url"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// type Configuration struct {
// 	TERRAFORM_DIR string
// 	REGION     string
// }

// func LoadConfigFile() Configuration {
// 	file, err := os.Open("./config.json")

// 	if err != nil {
// 		log.Fatal("Can't open config file: ", err)
// 	}

// 	defer file.Close()

// 	decoder := json.NewDecoder(file)
// 	Config := Configuration{}
// 	err = decoder.Decode(&Config)

// 	if err != nil {
// 		log.Fatal("can't decode config JSON: ", err)
// 	}

// 	// log.(Config.TERRAFORM_DIR)
// 	// log.Println(Config.REGION)
// 	return Config
// }

// Standard Go test, with the "Test" prefix and accepting the *testing.T struct.
// func TestS3Bucket(t *testing.T) {
	// // Load configuration file
	// config := LoadConfigFile()

	// // This is using the terraform package that has a sensible retry function.
	// terraformOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
	// 	// Our Terraform code is in the /terraformTask folder.
	// 	TerraformDir: config.TERRAFORM_DIR,

	// 	// This allows us to define Terraform variables. We have a variable named "bucket_name" to use it in our testing.
		// Vars: map[string]interface{}{
		// 	"bucket_name": fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
		// },

	// 	// Setting the environment variables, specifically the AWS region.
	// 	EnvVars: map[string]string{
	// 		"AWS_DEFAULT_REGION": config.REGION,
	// 	},
	// })

	// // // To destroy the infrastructure after testing.
	// // defer terraform.Destroy(t, terraformOpts)

	// // // Deploy the infrastructure with the options defined above
	// // terraform.InitAndApply(t, terraformOpts)

	// // Get the bucket ID so we can query AWS
	// bucketID := terraform.Output(t, terraformOpts, "bucket_id")

	// // Test that the bucket exists.
	// actualBucketStatus := aws.AssertS3BucketExistsE(t, config.REGION, bucketID)
	// assert.Equal(t, nil, actualBucketStatus)

	// // Test there is 2 files with names "file1.txt" and "file2.txt"
	// actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, config.REGION, bucketID, "test1.txt")
	// actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, config.REGION, bucketID, "testt2.txt")

	// // Assert files were uploaded by checking returned content is not null and of type strings
	// assert.NotEqual(t, nil, actualBucketObject1Content)
	// assert.IsType(t, "", actualBucketObject1Content)
	// assert.NotEqual(t, nil, actualBucketObject2Content)
	// assert.IsType(t, "", actualBucketObject2Content)
// }

// func TestTerraformAwsNetwork(t *testing.T) {
	// t.Parallel()
	
	// // Load configuration file
	// config := LoadConfigFile()

	
	// // Give the VPC and the subnets correct CIDRs
	// vpcCidr := "10.0.0.0/16"
	// publicSubnetCidr1  := "10.0.0.0/24"
	// publicSubnetCidr2 := "10.0.1.0/24"
	// awsRegion := "eu-west-1"

	// // Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// // terraform testing.
	// terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
	// 	// The path to where our Terraform code is located
	// 	TerraformDir: config.TERRAFORM_DIR,

	// 	// Variables to pass to our Terraform code using -var options
	// 	Vars: map[string]interface{}{
	// 		"main_vpc_cidr":       vpcCidr,
	// 		"first_subnet_cidr": publicSubnetCidr1,
	// 		"second_subnet_cidr":  publicSubnetCidr2,
	// 		"aws_region":          awsRegion,
	// 	},
	// })

// 	// At the end of the test, run `terraform destroy` to clean up any resources that were created
// 	defer terraform.Destroy(t, terraformOptions)

// 	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
// 	terraform.InitAndApply(t, terraformOptions)

// 	// Run `terraform output` to get the value of an output variable
// 	publicSubnetId1 := terraform.Output(t, terraformOptions, "public1_subnet_id")
// 	publicSubnetId2 := terraform.Output(t, terraformOptions, "public2_subnet_id")
// 	vpcId := terraform.Output(t, terraformOptions, "main_vpc_id")

// 	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)

// 	require.Equal(t, 2, len(subnets))
// 	// Verify if the network that is supposed to be public is really public
// 	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId1, awsRegion))
// 	// Verify if the network that is supposed to be public is really public
// 	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId2, awsRegion))
// }

// func TestTerraformAwsExample(t *testing.T) {
// 	t.Parallel()

// 		// Load configuration file
// 	config := LoadConfigFile()

// 	// Give this EC2 Instance a unique ID for a name tag so we can distinguish it from any other EC2 Instance running
// 	// in your AWS account
// 	expectedName := fmt.Sprintf("terratest-aws-%s", random.UniqueId())
// 	expectedName2 := fmt.Sprintf("terratest-aws-%s", random.UniqueId())
// 	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
// 	awsRegion := "eu-west-1"

// 	// Some AWS regions are missing certain instance types, so pick an available type based on the region we picked
// 	instanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.micro"})
// 	instanceType2 := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.micro"})
// 	// website::tag::1::Configure Terraform setting path to Terraform code, EC2 instance name, and AWS Region. We also
// 	// configure the options with default retryable errors to handle the most common retryable errors encountered in
// 	// terraform testing.
// 	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
// 		// The path to where our Terraform code is located
// 		TerraformDir: config.TERRAFORM_DIR,

// 		// Variables to pass to our Terraform code using -var options
// 		Vars: map[string]interface{}{
// 			"instance_name1": expectedName,
// 			"instance_type1": instanceType,
// 			"instance_name2": expectedName2,
// 			"instance_type2": instanceType2,
// 		},

// 		// Environment variables to set when running Terraform
// 		EnvVars: map[string]string{
// 			"AWS_DEFAULT_REGION": awsRegion,
// 		},
// 	})

// 	// website::tag::4::At the end of the test, run `terraform destroy` to clean up any resources that were created
// 	defer terraform.Destroy(t, terraformOptions)

// 	// website::tag::2::Run `terraform init` and `terraform apply` and fail the test if there are any errors
// 	terraform.InitAndApply(t, terraformOptions)

// 	// Run `terraform output` to get the value of an output variable
// 	instanceID := terraform.Output(t, terraformOptions, "instance_id1")
// 	instanceID2 := terraform.Output(t, terraformOptions, "instance_id2")

// 	aws.AddTagsToResource(t, awsRegion, instanceID, map[string]string{"testing": "testing-tag-value"})
// 	aws.AddTagsToResource(t, awsRegion, instanceID2, map[string]string{"testing": "testing-tag-value"})
// 	// Look up the tags for the given Instance ID
// 	instanceTags := aws.GetTagsForEc2Instance(t, awsRegion, instanceID)
// 	instanceTags2 := aws.GetTagsForEc2Instance(t, awsRegion, instanceID2)
// 	// website::tag::3::Check if the EC2 instance with a given tag and name is set.
// 	testingTag, containsTestingTag := instanceTags["testing"]
// 	assert.True(t, containsTestingTag)
// 	assert.Equal(t, "testing-tag-value", testingTag)

// 	testingTag2, containsTestingTag2 := instanceTags2["testing"]
// 	assert.True(t, containsTestingTag2)
// 	assert.Equal(t, "testing-tag-value", testingTag2)

// 	// Verify that our expected name tag is one of the tags
// 	nameTag, containsNameTag := instanceTags["Name"]
// 	assert.True(t, containsNameTag)
// 	assert.Equal(t, expectedName, nameTag)

// 	nameTag2, containsNameTag2 := instanceTags2["Name"]
// 	assert.True(t, containsNameTag2)
// 	assert.Equal(t, expectedName, nameTag2)

// }


// import (
// 	"crypto/tls"
// 	"fmt"
// 	"strings"
// 	"testing"
// 	"time"

// 	"github.com/gruntwork-io/terratest/modules/aws"
// 	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
// 	// "github.com/gruntwork-io/terratest/modules/logger"
// 	"github.com/gruntwork-io/terratest/modules/random"
// 	// "github.com/gruntwork-io/terratest/modules/retry"
// 	"github.com/gruntwork-io/terratest/modules/terraform"
// 	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
// 	"github.com/stretchr/testify/assert"
// 	"github.com/stretchr/testify/require"
// 	"log"
// )

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

	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	test_structure.RunTestStage(t, "pick_region", func() {
		awsRegion := "eu-west-1"
		// Save the region, so that we reuse the same region when we skip stages
		test_structure.SaveString(t, workingDir, "region", awsRegion)
	})

	// At the end of the test, clean up all the resources we created
	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	// // At the end of the test, fetch the logs from each Instance. This can be useful for
	// // debugging issues without having to manually SSH to the server.
	// defer test_structure.RunTestStage(t, "logs", func() {
	// 	awsRegion := test_structure.LoadString(t, workingDir, "region")
	// 	fetchSyslogForAsg(t, awsRegion, workingDir)
	// 	fetchFilesFromAsg(t, awsRegion, workingDir)
	// })

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
		publicSubnetCidr1  := "10.0.0.0/24"
		publicSubnetCidr2 := "10.0.1.0/24"
	// Create a KeyPair we can use later to SSH to each Instance
	// keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)

	keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, workingDir, keyPair)
	// test_structure.SaveEc2KeyPair(t, workingDir, keyPair)

	// Give the ASG and other resources in the Terraform code a name with a unique ID so it doesn't clash
	// with anything else in the AWS account.
	name := fmt.Sprintf("terraTest-%s", uniqueID)

	// // This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	// terraform.InitAndApply(t, terraformOptions)
	// Specify the text the ASG will return when we make HTTP requests to it.
	// text := fmt.Sprintf("Hello, %s!", uniqueID)

	// Some AWS regions are missing certain instance types, so pick an available type based on the region we picked
	instanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.micro"})

	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: workingDir,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"aws_region":    awsRegion,
			"instance_name": name,
			"instance_type": instanceType,
			"key_pair_name": keyPair.Name,
			"bucket_name": fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
			"main_vpc_cidr":       vpcCidr,
			"first_subnet_cidr": publicSubnetCidr1,
			"second_subnet_cidr":  publicSubnetCidr2,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

		// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
		terraform.InitAndApply(t, terraformOptions)
/////////////////////////////////////////////////////////////////////////////////


	// This is using the terraform package that has a sensible retry function.
	// terraformOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
	// 	// Our Terraform code is in the /terraformTask folder.


	// 	// Setting the environment variables, specifically the AWS region.
	// 	// EnvVars: map[string]string{
	// 	// 	"AWS_DEFAULT_REGION": awsRegion,
	// 	// },
	// })


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

/////////////////////////////////////////////////////////////////////////////////1

//////////////////////////////////////////////////////////////////////////////////////////
t.Parallel()
	
	// Load configuration file
	// config := LoadConfigFile()

	


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

		// Variables to pass to our Terraform code using -var options

	
//////////////////////////////////////////////////////////////////////////////////////2

	// Save the Terraform Options struct so future test stages can use it
	test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)

	// // This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	// terraform.InitAndApply(t, terraformOptions)
}





const file1 = "/home/ubuntu/file1_access.txt"
const file2 = "/home/ubuntu/file2_access.txt"
// This size is configured in the terraform-redeploy-example itself
const asgSize = 2

// Default location where the User Data script generates a presign url for the files.


const fileContent = ""
const fileContent2 = ""

// Validate the ASG has been deployed and is working
func validateAsgRunningWebServer(t *testing.T, awsRegion string, workingDir string) {
	// Load the Terraform Options saved by the earlier deploy_terraform stage
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	keyPair := test_structure.LoadEc2KeyPair(t, workingDir)
	// Run `terraform output` to get the value of an output variable
	url := terraform.Output(t, terraformOptions, "url")
	expectedText := terraform.Output(t, terraformOptions, "time_stamp")
	log.Println(url)
	log.Println(expectedText)
	

	asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")
	instanceIdToFilePathToContents := aws.FetchContentsOfFilesFromAsg(t, awsRegion, "ubuntu", keyPair, asgName, true, file1, file2)
	
	// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
	tlsConfig := tls.Config{}
	require.Len(t, instanceIdToFilePathToContents, asgSize)
	// Wait and verify the ASG is scaled to the desired capacity. It can take a few minutes for the ASG to boot up, so
	// retry a few times.
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	aws.WaitForCapacity(t, asgName, awsRegion, maxRetries, timeBetweenRetries)
	capacityInfo := aws.GetCapacityInfoForAsg(t, asgName, awsRegion)
	assert.Equal(t, capacityInfo.DesiredCapacity, int64(2))
	assert.Equal(t, capacityInfo.CurrentCapacity, int64(2))

	// Figure out what text the ASG should return for each request
	

	for _, filePathToContents := range instanceIdToFilePathToContents {
		fileContent := filePathToContents[file1]
		fileContent2 := filePathToContents[file2]
		log.Println(fileContent)
		log.Println(fileContent2)
	  }
	  
	//   expectedText := fileContent
	// expectedText := terraform.Output(t, terraformOptions, "time_stamp")
	s3url := strings.Replace(fileContent, "https://.s3.amazonaws.com/", "", -1)
	s3url2 := strings.Replace(fileContent2, "https://.s3.amazonaws.com/", "", -1)
	fullURL1 :=fmt.Sprintf("%s%s", url, s3url)
	fullURL2 :=fmt.Sprintf("%s%s", url, s3url2)

	
	// Verify that we get back a 200 OK with the expectedText
	// It can take a few minutes for the ALB to boot up, so retry a few times
	// http_helper.HttpGetWithRetry(t, url, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
	http_helper.HttpGetWithRetry(t, fullURL1, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
	http_helper.HttpGetWithRetry(t, fullURL2, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
}

func BuildLbUrl(file_url string, lb_url string) string {
    file_url_parsed, e := url.Parse(file_url)

    if e != nil {
        log.Fatal(e)
    }

    file_url_parsed.Host = lb_url

    return file_url_parsed.String()
}

// func fetchFilesFromAsg(t *testing.T, awsRegion string, workingDir string) {
// 	// Load the Terraform Options and Key Pair saved by the earlier deploy_terraform stage
// 	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
// 	keyPair := test_structure.LoadEc2KeyPair(t, workingDir)

// 	asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")
// 	instanceIdToFilePathToContents := aws.FetchContentsOfFilesFromAsg(t, awsRegion, "ubuntu", keyPair, asgName, true, file1, file2)
// 	instanceIdToFilePathToContents2 := aws.FetchContentsOfFilesFromAsg(t, awsRegion, "ubuntu", keyPair, asgName, true, file2)
	
// 	require.Len(t, instanceIdToFilePathToContents, asgSize)
// 	require.Len(t, instanceIdToFilePathToContents2, asgSize)

// 	for _, filePathToContents := range instanceIdToFilePathToContents {
// 		fileContent := filePathToContents[file1]
// 		fileContent2 := filePathToContents[file2]
// 	  }
	  
// 	  log.Println(fileContent)
// 	  log.Println(fileContent2)


// 	// Check that the index.html file on each Instance contains the expected text
// 	expectedText := terraformOptions.Vars["instance_text"]
// 	for instanceID, filePathToContents := range instanceIdToFilePathToContents {
// 		require.Contains(t, filePathToContents, indexHtmlUbuntu)
// 		assert.Equal(t, expectedText, strings.TrimSpace(filePathToContents[indexHtmlUbuntu]), "Expected %s on instance %s to contain %s", indexHtmlUbuntu, instanceID, expectedText)
// 	}

	
// }