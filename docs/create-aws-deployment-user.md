# Creating an AWS User for TrustAInvest Deployment

This guide provides step-by-step instructions for creating a dedicated AWS IAM user with the necessary permissions to deploy the TrustAInvest system.

## Overview

Creating a dedicated IAM user for deployment is a security best practice. It allows you to:

1. Follow the principle of least privilege by granting only the permissions needed for deployment
2. Easily revoke access if needed
3. Track actions performed by the deployment process
4. Avoid using your root account or personal IAM user for automated deployments

## Prerequisites

- An AWS account with administrator access
- Access to the AWS Management Console

## Step 1: Sign in to the AWS Management Console

1. Go to [https://console.aws.amazon.com/](https://console.aws.amazon.com/)
2. Sign in with your AWS account credentials

## Step 2: Create a New IAM User

1. Navigate to the IAM service:
   - Click on "Services" in the top navigation bar
   - Type "IAM" in the search box
   - Select "IAM" from the search results

2. Create a new user:
   - In the left navigation pane, click on "Users"
   - Click the "Create user" button
   - Enter a user name (e.g., `trust-ai-deployment`)
   - **Console access decision**:
     - If you only need programmatic access for deployment (recommended for automation): Leave the "Provide user access to the AWS Management Console" box **unchecked**
     - If you need to manually access the console with this user: Check the box and select "I want to create an IAM user"
   - Click "Next"

3. Set permissions:
   - On the "Set permissions" page, select "Attach policies directly"
   - We'll create a custom policy in the next step, so don't attach any policies yet
   - Click "Next"

4. Review and create:
   - Review the user details
   - Click "Create user"

## Step 3: Create a Custom Policy for TrustAInvest Deployment

1. Navigate to policies:
   - In the left navigation pane, click on "Policies"
   - Click the "Create policy" button

2. Create the policy:
   - Select the JSON tab
   - Copy and paste the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "elasticloadbalancing:*",
                "ecs:*",
                "ecr:*",
                "logs:*",
                "cloudwatch:*",
                "cloudfront:*",
                "route53:*",
                "s3:*",
                "rds:*",
                "elasticache:*",
                "iam:GetRole",
                "iam:PassRole",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:ListRoles",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:TagRole",
                "iam:CreateServiceLinkedRole",
                "kms:*",
                "cognito-idp:*",
                "sns:*",
                "sqs:*",
                "wafv2:*",
                "application-autoscaling:*",
                "servicediscovery:*"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "us-east-1"
                }
            }
        }
    ]
}
```

   - This policy grants the necessary permissions to deploy the TrustAInvest infrastructure
   - The condition restricts the permissions to the us-east-1 region (modify if using a different region)
   - Click "Next"

   > **Note**: This updated policy includes additional permissions required for service-linked roles and service discovery. For more details, see the [Terraform Deployment Permissions Guide](terraform-deployment-permissions.md).

3. Review and create the policy:
   - Name the policy `TrustAInvestDeploymentPolicy`
   - Add a description: "Policy for deploying TrustAInvest infrastructure and services"
   - Click "Create policy"

## Step 4: Attach the Policy to the User

1. Navigate back to the user:
   - In the left navigation pane, click on "Users"
   - Click on the user you created (`trust-ai-deployment`)

2. Attach the policy:
   - Click on the "Permissions" tab
   - Click "Add permissions"
   - Select "Attach policies directly"
   - Search for `TrustAInvestDeploymentPolicy`
   - Check the box next to the policy
   - Click "Add permissions"

## Step 5: Create Access Keys for Programmatic Access

1. Navigate to the Security credentials tab:
   - Click on the "Security credentials" tab for your user

2. Create access keys:
   - Scroll down to the "Access keys" section
   - Click "Create access key"
   - Select "Command Line Interface (CLI)"
   - Check the box acknowledging the recommendation
   - Click "Next"
   - (Optional) Add a description tag
   - Click "Create access key"

3. Save the credentials:
   - You will see the Access key ID and Secret access key
   - Click "Download .csv file" to save the credentials
   - **Important**: This is the only time you can view or download the secret access key
   - Click "Done"

## Step 6: Configure AWS CLI with the New Credentials

1. Install the AWS CLI if you haven't already:
   - Follow the [official installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

2. Configure the AWS CLI:
   - Open a terminal or command prompt
   - Run the following command:

```bash
aws configure --profile trustainvest
```

3. Enter the credentials when prompted:
   - AWS Access Key ID: Enter the access key ID from the previous step
   - AWS Secret Access Key: Enter the secret access key from the previous step
   - Default region name: Enter `us-east-1` (or your preferred region)
   - Default output format: Enter `json`

4. Verify the configuration:
   - Run the following command to verify that the credentials are working:

```bash
aws sts get-caller-identity --profile trustainvest
```

   - You should see output with your account ID and the ARN of the IAM user

## Step 7: Use the New User for Deployment

### Local Deployment

When deploying from your local machine, use the profile you created:

```bash
export AWS_PROFILE=trustainvest
cd deployments/terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Or specify the profile for each command:

```bash
aws --profile trustainvest ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### GitHub Actions

For GitHub Actions, add the access keys as secrets in your GitHub repository:

1. Go to your GitHub repository
2. Click on "Settings" > "Secrets and variables" > "Actions"
3. Click on "New repository secret"
4. Add the following secrets:
   - `AWS_ACCESS_KEY_ID`: The access key ID of the deployment user
   - `AWS_SECRET_ACCESS_KEY`: The secret access key of the deployment user
   - `TF_VAR_DB_PASSWORD`: The password for the database

## Security Considerations

1. **Principle of Least Privilege**: The policy provided grants broad permissions for deployment. For production environments, consider further restricting the permissions to only what is necessary.

2. **Access Key Rotation**: Regularly rotate the access keys for the deployment user:
   - Create new access keys
   - Update your configuration to use the new keys
   - Verify that everything works with the new keys
   - Delete the old access keys

3. **MFA**: Consider enabling Multi-Factor Authentication (MFA) for the deployment user if it will be used for console access.

4. **IP Restrictions**: Consider adding IP restrictions to the policy to only allow access from specific IP addresses.

5. **Monitoring**: Enable CloudTrail and set up alerts for suspicious activities performed by the deployment user.

## Troubleshooting

If you encounter permission issues during deployment:

1. Check the error message to identify the missing permission
2. Add the required permission to the policy
3. If using GitHub Actions, ensure that the secrets are correctly set
4. Verify that the user has the policy attached
5. Check that you're using the correct profile or credentials
6. Refer to the [Terraform Deployment Permissions Guide](terraform-deployment-permissions.md) for common permission issues and solutions

## Next Steps

Now that you have created a dedicated user for deployment, you can proceed with deploying the TrustAInvest infrastructure and services as described in the [AWS Deployment Guide](aws-deployment.md).
