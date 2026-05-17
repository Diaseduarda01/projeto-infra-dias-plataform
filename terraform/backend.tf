# Descomente após criar o bucket e a tabela DynamoDB manualmente (terraform init -migrate-state)
# terraform {
#   backend "s3" {
#     bucket         = "dias-platform-tfstate"
#     key            = "global/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "dias-platform-tfstate-lock"
#   }
# }

# Para criar o bucket de state e a lock table:
# aws s3api create-bucket --bucket dias-platform-tfstate --region us-east-1
# aws dynamodb create-table \
#   --table-name dias-platform-tfstate-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
