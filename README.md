# Example code to show how to integrate Auth0 with AWS AppSync

## Prerequisites

* AWS account
* Terraform installed and configured
* Auth0 account

## Setup Auth0 for Terraform

* Go to the documentation page: https://marketplace.auth0.com/integrations/terraform
* and follow the **Create a Machine to Machine Application** chapter

## Deploy

* ```terraform init```
* ```terraform apply```

## Use

* Go to the URL Terraform prints
* Log in with either ```user1@example.com``` // ```Password.1``` or ```user2@example.com``` // ```Password.1```
* The page shows the ```context.identity``` values AppSync gets

## Cleanup

* ```terraform destroy```
