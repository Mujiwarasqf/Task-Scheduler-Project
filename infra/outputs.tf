output "api_base_url"     { value = aws_apigatewayv2_api.api.api_endpoint }
output "cloudfront_url"   { value = "https://${aws_cloudfront_distribution.cdn.domain_name}" }
output "ui_bucket_name"   { value = aws_s3_bucket.ui.bucket }

output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.cdn.id }