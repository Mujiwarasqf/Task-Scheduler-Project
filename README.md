# Daily Task Scheduler

A serverless task management application built on AWS with a modern web interface. Schedule tasks with due dates and times, receive email notifications, and manage your daily workflow efficiently.

## 🏗️ Architecture

- **Frontend**: Static HTML/JS hosted on S3 + CloudFront
- **Backend**: API Gateway + Lambda functions (Python 3.12)
- **Database**: DynamoDB with GSI for due date queries
- **Notifications**: SNS email alerts for due tasks
- **Scheduling**: EventBridge Scheduler (daily 8 AM London time)
- **Infrastructure**: Terraform for complete AWS deployment

## ✨ Features

- ✅ Create tasks with titles and optional due dates/times
- ✅ Mark tasks as complete
- ✅ Real-time London timezone display
- ✅ Email notifications for tasks due today
- ✅ Responsive web interface
- ✅ Multi-user support with user IDs
- ✅ Serverless and cost-effective

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- Valid email address for notifications

### Local Deployment

1. **Clone and navigate to infrastructure**
   ```bash
   git clone https://github.com/Mujiwarasqf/Task-Scheduler-Project.git
   cd Task-Scheduler-Project/infra
   ```

2. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan -var="email=your@email.com"
   terraform apply -var="email=your@email.com"
   ```

3. **Get your application URL**
   ```bash
   terraform output cloudfront_url
   ```

4. **Confirm SNS subscription** (check your email and click the confirmation link)

### GitHub Actions Deployment

1. **Set up repository secrets**:
   - `AWS_ROLE_TO_ASSUME`: Your AWS IAM role ARN for OIDC
   - `AWS_REGION`: `eu-west-2` (optional)

2. **Push to main branch** - automatic deployment via GitHub Actions

## 📁 Project Structure

```
Task-Scheduler-Project/
├── infra/
│   ├── main.tf              # Main Terraform configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf          # Output values
│   ├── lambdas/            # Lambda function code
│   │   ├── create_task.py
│   │   ├── list_tasks.py
│   │   ├── complete_task.py
│   │   └── notify_due_today.py
│   └── ui/                 # Frontend files
│       ├── index.html
│       └── app.js
├── .github/workflows/      # CI/CD pipelines
│   ├── terraform-plan.yml
│   └── terraform-apply.yml
├── README.md
├── README_CI.md
└── .gitignore
```

## 🔧 Configuration

### Variables
- `aws_region`: AWS region (default: `eu-west-2`)
- `project`: Project name prefix (default: `daily-task-scheduler`)
- `email`: Email address for notifications (required)

### Outputs
- `api_base_url`: API Gateway endpoint
- `cloudfront_url`: Web application URL
- `ui_bucket_name`: S3 bucket name
- `cloudfront_distribution_id`: CloudFront distribution ID

## 📱 Usage

1. **Open the web application** using the CloudFront URL
2. **Add tasks** with title, optional due date, and time
3. **View tasks** by user ID (default: "demo")
4. **Complete tasks** by clicking the Complete button
5. **Receive notifications** via email for tasks due today at 8 AM London time

## 🛠️ Development

### Local Testing
```bash
# Format Terraform code
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan -var="email=test@example.com"
```

### Lambda Functions
- **create_task.py**: Creates new tasks in DynamoDB
- **list_tasks.py**: Retrieves tasks for a user
- **complete_task.py**: Marks tasks as completed
- **notify_due_today.py**: Sends email notifications for due tasks

## 🔒 Security

- S3 bucket with public access blocked
- CloudFront Origin Access Control (OAC) for secure S3 access
- IAM roles with least privilege principles
- HTTPS-only access via CloudFront

## 💰 Cost Optimization

- DynamoDB Pay-per-Request billing
- Lambda functions with minimal memory allocation
- CloudFront PriceClass_100 (US, Canada, Europe)
- S3 Standard storage class

## 🚨 Troubleshooting

### Common Issues

**API not working**: Ensure API Gateway stage is deployed
```bash
# Check if stage exists
aws apigatewayv2 get-stages --api-id <your-api-id>
```

**CloudFront serving old content**: Invalidate cache
```bash
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

**Email notifications not working**: Confirm SNS subscription in your email

## 🔑 AWS OIDC Setup

To set up GitHub Actions with AWS OIDC:

1. **Create IAM OIDC Provider**:
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Create IAM Role** with trust policy for GitHub:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:Mujiwarasqf/Task-Scheduler-Project:*"
           }
         }
       }
     ]
   }
   ```

3. **Add role ARN to GitHub secrets** as `AWS_ROLE_TO_ASSUME`

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting section above
- Review AWS CloudWatch logs for Lambda functions