# Terraform ALB to serve private S3 files.

Terraform configuratiion to create full infrastructure (Network, S3, IAM role, policies, autoscalling group and ALB)
Two subnets in the VPC and both are public.
The ALB forwards requests to autoscalling group which host Traefik.
Traefik is working as reverse proxy to redirect all incoming traffic on port 80 to S3 bucket URL.
No one has power over the S3 bucket but the instances.
Once the instances boot up, they will run bash script to install awscli.
Instances will also generate a presigned URL for the files and echo the output into 2 files (it will be later used to access the files).
The load balancer URL itself will not be able to access the files, you must have S3 creds to be able to access them.
Terratest to check the above actions are executed correctly, and the files are accessible/correct from the load balancer url + the S3 creds.

For the sake of testing, I have set the default instances type to t2.xlarge so testing becomes much faster.

### Prerequisites
* [Terraform](https://www.terraform.io/downloads.html)
* [Go](https://golang.org/dl/)
* Export AWS access keys to Github to be used in github actions.

1. On GitHub, navigate to the main page of the repository.
2. Under your repository name, click  Settings.
3. Repository settings button
4. In the left sidebar, click Secrets.
5. Click New repository secret.
6. Type a name for your secret in the Name input box.
7. Enter the value for your secret.
8. Click Add secret.


### 1. Manual

### Steps
* Initializing terraform modules.
 ```sh
  terraform init
  ``` 

* Check what changes will occur once ran.
 ```sh
  terraform plan
  ``` 
* Apply changes.
 ```sh
  terraform apply -auto-approve
  ``` 

* You should find a new S3 bucket created with 2 files with the timestamp in them.

### Use Terratest to apply the changes and test if the bucket and the files exist or not.
* It will run both terraform init and terraform apply to create a bucket with a random name then run tests to check if the bucket and the files were created successfully, it will destroy everything after it completes and it should return "PASS" at the end.
 ```sh
  cd test
  go get "needed dependencies"
  go test -v
  ```
  
### 2. Github actions (automated).
  
 * After adding your AWS keys to github secrets, workflow can use them to create the S3 bucket and list whats inside of it.
 
  ```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

* Workflow is configured to run once a push is made to the branch.
```yaml
on: 
  push:
    branches:
      - task
```


* It will clone the repo, install Go, install the dependencies and test it for you.

```yaml
    - name: Test
      working-directory: /home/runner/work/terraformTask/terraformTask/test
      run: go test -v
```

### Test
* Testing is divided into 2 stages, and once its done it will destroy everything it has created.
  1. The infrastructure is built correctly.
  2. The files are reachable from the final URL and has the correct time stamp in them.

* Import the needed modules to be used in our code.

```go
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
```

* initialDeploy function to start building of the infrastructure, everything will be created and have a unique name so it does not collide with anything that already exists on AWS.

* Test S3 bucket exists and has the correct files.

```go
  actualBucketStatus := aws.AssertS3BucketExistsE(t, awsRegion, bucketID)
	assert.Equal(t, nil, actualBucketStatus)

	actualBucketObject1Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "test1.txt")
	actualBucketObject2Content, _ := aws.GetS3ObjectContentsE(t, awsRegion, bucketID, "testt2.txt")

	assert.NotEqual(t, nil, actualBucketObject1Content)
	assert.IsType(t, "", actualBucketObject1Content)
	assert.NotEqual(t, nil, actualBucketObject2Content)
	assert.IsType(t, "", actualBucketObject2Content)
```

* Test subnets exist in the VPC and publicly accessible.

```go
	publicSubnetId1 := terraform.Output(t, terraformOptions, "public1_subnet_id")
	publicSubnetId2 := terraform.Output(t, terraformOptions, "public2_subnet_id")
	vpcId := terraform.Output(t, terraformOptions, "main_vpc_id")

	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)
	require.Equal(t, 2, len(subnets))

	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId1, awsRegion))
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId2, awsRegion))
```

* During the test we need to fetch the URL from the files on the EC2 instances, it might take a while for the instances to finish booting, so we have to create a function that keeps retying until it finally succeeds.

```go
func retryToGetFiles(t *testing.T, awsRegion string, keyPair *aws.Ec2Keypair, asgName string, file1 string, file2 string) (map[string]map[string]string, error) {
	fileContentsMaxTries := 30
	fileContentSleepTime := 60 * time.Second

	for i := 0; i < fileContentsMaxTries; i++ {
		logger.Logf(t, "[%d] Trying to get files contents, it might take a while", i)
		instanceIdToFilePathToContents, filesContentsError := aws.FetchContentsOfFilesFromAsgE(t, awsRegion, "ubuntu", keyPair, asgName, true, file1, file2)

		if filesContentsError == nil {
			return instanceIdToFilePathToContents, nil
		}

		logger.Logf(t, "[%d] Failed to get the files, Retrying again in 1 minute ....", i)
		time.Sleep(fileContentSleepTime)
	}

	return nil, errors.New("Failed to get files contents")
}
```

* Validating that the ASG is at desired capacity (which in our case is 2)

```go
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	aws.WaitForCapacity(t, asgName, awsRegion, maxRetries, timeBetweenRetries)
	capacityInfo := aws.GetCapacityInfoForAsg(t, asgName, awsRegion)
	assert.Equal(t, capacityInfo.DesiredCapacity, int64(2))
	assert.Equal(t, capacityInfo.CurrentCapacity, int64(2))
}
```

* The presigned URL has the S3 bucket url + S3 creds, since no one has access to the S3 bucket but the instances, we need to replace the S3 hostname with the load balancer hostname, so the final result is the load balancer URL + S3 creds that will allow us to access the filees, and you would be able to access the files through the load balancer.
* In this function we rebuild the fetched URL to match our needs.

```go
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
```

* Finally we check that the URL contains the correct value (which is the time stamp we created earlier) and returns status code of 200.

```go
func BuildLbUrl(file_url string, lb_url *url.URL) string {
			http_helper.HttpGetWithRetry(t, fullURL1, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
			http_helper.HttpGetWithRetry(t, fullURL2, &tlsConfig, 200, expectedText, maxRetries, timeBetweenRetries)
```


### ENJOY !!!!