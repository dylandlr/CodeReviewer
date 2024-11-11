# Import environment variables
Get-Content .env | ForEach-Object {
    $name, $value = $_.split('=')
    if ($name -and $value) {
        Set-Item -Path env:$name -Value $value
    }
}

# Test AWS CLI setup
Write-Host "Testing AWS CLI configuration..."
aws sts get-caller-identity

if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI is not configured correctly. Please run 'aws configure' first."
    exit 1
}

Write-Host "AWS CLI is configured correctly."
Write-Host "Region: $env:AWS_REGION"
Write-Host "Project: $env:PROJECT_NAME"
Write-Host "Environment: $env:ENVIRONMENT"
