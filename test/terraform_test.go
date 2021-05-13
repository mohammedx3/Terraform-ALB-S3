package test

import (
  "fmt"
  "strings"
  "github.com/gruntwork-io/terratest/modules/random"
  "testing"
  "github.com/gruntwork-io/terratest/modules/aws"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/stretchr/testify/assert"
)

// Standard Go test, with the "Test" prefix and accepting the *testing.T struct.
func TestS3Bucket(t *testing.T) {
  // Set AWS region.
  awsRegion := "eu-west-1"

  // This is using the terraform package that has a sensible retry function.
  terraformOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    // Our Terraform code is in the /terraformTask folder.
    TerraformDir: "../",
    
    // This allows us to define Terraform variables. We have a variable named "bucket_name" to use it in our testing.
    Vars: map[string]interface{}{
      "bucket_name": fmt.Sprintf("%v", strings.ToLower(random.UniqueId())),
    },

    // Setting the environment variables, specifically the AWS region.
    EnvVars: map[string]string{
      "AWS_DEFAULT_REGION": awsRegion,
    },
  })

  // To destroy the infrastructure after testing.
  defer terraform.Destroy(t, terraformOpts)

  // Deploy the infrastructure with the options defined above
  terraform.InitAndApply(t, terraformOpts)

  // Get the bucket ID so we can query AWS
  bucketID := terraform.Output(t, terraformOpts, "bucket_id")

  // Test that the bucket exists.
  actualBucketStatus := aws.AssertS3BucketExistsE(t, awsRegion, bucketID)
  assert.Equal(t, nil, actualBucketStatus)
  // Test there is 2 files with names "file1.txt" and "file2.txt"
  actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "file1.txt")
  actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "file2.txt")
  assert.NotEqual(t, nil, actualBucketObject1Content)
  assert.NotEqual(t, nil, actualBucketObject2Content)


}
