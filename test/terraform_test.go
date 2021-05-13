package test

import (
	"fmt"
	"strings"
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
	S3_REGION     string
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
	log.Println(Config.S3_REGION)
	return Config
}

// Standard Go test, with the "Test" prefix and accepting the *testing.T struct.
func TestS3Bucket(t *testing.T) {
	// Load configuration file
	config := LoadConfigFile()

	// This is using the terraform package that has a sensible retry function.
	terraformOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Our Terraform code is in the /terraformTask folder.
		TerraformDir: config.TERRAFORM_DIR,

		// This allows us to define Terraform variables. We have a variable named "bucket_name" to use it in our testing.
		Vars: map[string]interface{}{
			"bucket_name": fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
		},

		// Setting the environment variables, specifically the AWS region.
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": config.S3_REGION,
		},
	})

	// To destroy the infrastructure after testing.
	defer terraform.Destroy(t, terraformOpts)

	// Deploy the infrastructure with the options defined above
	terraform.InitAndApply(t, terraformOpts)

	// Get the bucket ID so we can query AWS
	bucketID := terraform.Output(t, terraformOpts, "bucket_id")

	// Test that the bucket exists.
	actualBucketStatus := aws.AssertS3BucketExistsE(t, config.S3_REGION, bucketID)
	assert.Equal(t, nil, actualBucketStatus)

	// Test there is 2 files with names "file1.txt" and "file2.txt"
	actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, config.S3_REGION, bucketID, "file1.txt")
	actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, config.S3_REGION, bucketID, "file2.txt")

	// Assert files were uploaded by checking returned content is not null and of type strings
	assert.NotEqual(t, nil, actualBucketObject1Content)
	assert.IsType(t, "", actualBucketObject1Content)
	assert.NotEqual(t, nil, actualBucketObject2Content)
	assert.IsType(t, "", actualBucketObject2Content)
}
