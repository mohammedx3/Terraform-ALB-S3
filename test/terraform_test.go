package test

import (
	// "github.com/stretchr/testify/require"
	"fmt"
	// "strings"
	"testing"

	"encoding/json"
	"log"
	"os"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

)

type Configuration struct {
	TERRAFORM_DIR string
	REGION     string
}

func LoadConfigFile() Configuration {
	file, err := os.Open("./config.json")

	if err != nil {
		log.Fatal("Can't open config file: ", err)
	}

	defer file.Close()

	decoder := json.NewDecoder(file)
	Config := Configuration{}
	err = decoder.Decode(&Config)

	if err != nil {
		log.Fatal("can't decode config JSON: ", err)
	}

	log.Println(Config.TERRAFORM_DIR)
	log.Println(Config.REGION)
	return Config
}

// Standard Go test, with the "Test" prefix and accepting the *testing.T struct.
// func TestS3Bucket(t *testing.T) {
// 	// Load configuration file
// 	config := LoadConfigFile()

// 	// This is using the terraform package that has a sensible retry function.
// 	terraformOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
// 		// Our Terraform code is in the /terraformTask folder.
// 		TerraformDir: config.TERRAFORM_DIR,

// 		// This allows us to define Terraform variables. We have a variable named "bucket_name" to use it in our testing.
// 		Vars: map[string]interface{}{
// 			"bucket_name": fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
// 		},

// 		// Setting the environment variables, specifically the AWS region.
// 		EnvVars: map[string]string{
// 			"AWS_DEFAULT_REGION": config.REGION,
// 		},
// 	})

// 	// To destroy the infrastructure after testing.
// 	defer terraform.Destroy(t, terraformOpts)

// 	// Deploy the infrastructure with the options defined above
// 	terraform.InitAndApply(t, terraformOpts)

// 	// Get the bucket ID so we can query AWS
// 	bucketID := terraform.Output(t, terraformOpts, "bucket_id")

// 	// Test that the bucket exists.
// 	actualBucketStatus := aws.AssertS3BucketExistsE(t, config.REGION, bucketID)
// 	assert.Equal(t, nil, actualBucketStatus)

// 	// Test there is 2 files with names "file1.txt" and "file2.txt"
// 	actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, config.REGION, bucketID, "test1.txt")
// 	actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, config.REGION, bucketID, "testt2.txt")

// 	// Assert files were uploaded by checking returned content is not null and of type strings
// 	assert.NotEqual(t, nil, actualBucketObject1Content)
// 	assert.IsType(t, "", actualBucketObject1Content)
// 	assert.NotEqual(t, nil, actualBucketObject2Content)
// 	assert.IsType(t, "", actualBucketObject2Content)
// }

// func TestTerraformAwsNetwork(t *testing.T) {
// 	t.Parallel()
	
// 	// Load configuration file
// 	config := LoadConfigFile()

	
// 	// Give the VPC and the subnets correct CIDRs
// 	vpcCidr := "10.0.0.0/16"
// 	publicSubnetCidr1  := "10.0.0.0/24"
// 	publicSubnetCidr2 := "10.0.1.0/24"
// 	awsRegion := "eu-west-1"

// 	// Construct the terraform options with default retryable errors to handle the most common retryable errors in
// 	// terraform testing.
// 	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
// 		// The path to where our Terraform code is located
// 		TerraformDir: config.TERRAFORM_DIR,

// 		// Variables to pass to our Terraform code using -var options
// 		Vars: map[string]interface{}{
// 			"main_vpc_cidr":       vpcCidr,
// 			"first_subnet_cidr": publicSubnetCidr1,
// 			"second_subnet_cidr":  publicSubnetCidr2,
// 			"aws_region":          awsRegion,
// 		},
// 	})

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

func TestTerraformAwsExample(t *testing.T) {
	t.Parallel()

		// Load configuration file
	config := LoadConfigFile()

	// Give this EC2 Instance a unique ID for a name tag so we can distinguish it from any other EC2 Instance running
	// in your AWS account
	expectedName := fmt.Sprintf("terratest-aws-%s", random.UniqueId())
	expectedName2 := fmt.Sprintf("terratest-aws-%s", random.UniqueId())
	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	awsRegion := "eu-west-1"

	// Some AWS regions are missing certain instance types, so pick an available type based on the region we picked
	instanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.micro"})
	instanceType2 := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.micro"})
	// website::tag::1::Configure Terraform setting path to Terraform code, EC2 instance name, and AWS Region. We also
	// configure the options with default retryable errors to handle the most common retryable errors encountered in
	// terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: config.TERRAFORM_DIR,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"instance_name1": expectedName,
			"instance_type1": instanceType,
			"instance_name2": expectedName2,
			"instance_type2": instanceType2,
		},

		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// website::tag::4::At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// website::tag::2::Run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	instanceID := terraform.Output(t, terraformOptions, "instance_id1")
	instanceID2 := terraform.Output(t, terraformOptions, "instance_id2")

	aws.AddTagsToResource(t, awsRegion, instanceID, map[string]string{"testing": "testing-tag-value"})
	aws.AddTagsToResource(t, awsRegion, instanceID2, map[string]string{"testing": "testing-tag-value"})
	// Look up the tags for the given Instance ID
	instanceTags := aws.GetTagsForEc2Instance(t, awsRegion, instanceID)
	instanceTags2 := aws.GetTagsForEc2Instance(t, awsRegion, instanceID2)
	// website::tag::3::Check if the EC2 instance with a given tag and name is set.
	testingTag, containsTestingTag := instanceTags["testing"]
	assert.True(t, containsTestingTag)
	assert.Equal(t, "testing-tag-value", testingTag)

	testingTag2, containsTestingTag2 := instanceTags2["testing"]
	assert.True(t, containsTestingTag2)
	assert.Equal(t, "testing-tag-value", testingTag2)

	// Verify that our expected name tag is one of the tags
	nameTag, containsNameTag := instanceTags["Name"]
	assert.True(t, containsNameTag)
	assert.Equal(t, expectedName, nameTag)

	nameTag2, containsNameTag2 := instanceTags2["Name"]
	assert.True(t, containsNameTag2)
	assert.Equal(t, expectedName, nameTag2)

}