# Terraform script to create AWS s3 bucket and 2 files in it with the timestamp when the script was executed.

### Terraform

### Prerequisites
* [Terraform](https://www.webpagefx.com/tools/emoji-cheat-sheet)
* [Go](https://golang.org/dl/)
* Export AWS access keys to Github to be used in github actions.

On GitHub, navigate to the main page of the repository.
Under your repository name, click  Settings.
Repository settings button
In the left sidebar, click Secrets.
Click New repository secret.
Type a name for your secret in the Name input box.
Enter the value for your secret.
Click Add secret.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      ```

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
