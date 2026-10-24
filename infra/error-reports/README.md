# Manual error reports (deployment pending)

The app error banner includes a manual Send error report button and confirmation preview. No automatic reporting. Only schema, numeric app/OS versions, fixed error category, and HTTP status are sent; raw error text and responses are excluded. The receiver rejects unknown fields and bodies over 1 KiB and adds a server-generated report ID/time. No IP or user agent is persisted by the handler.

Prepared AWS resources: private S3 bucket `link-card-error-logs-632163225962-us-west-2` with 30-day expiry, and role `link-card-error-reports` allowing only s3:PutObject under reports/. No app credentials or public S3 policy.

Pending explicit approval: deploy Python 3.13 Lambda with 128 MiB, 10-second timeout, reserved concurrency 2, and an unauthenticated HTTPS Function URL. A public endpoint can be abused and incur costs; concurrency and body-size limits are not a full rate limiter or spending cap. The deployment was not executed. No Lambda Function URL permissions have been created.

After approved deployment, configure ErrorReportURL in Info.plist, verify the HTTPS endpoint with synthetic reports and server-side rejected fields, then version/build/sign/publish. Without configuration the button reports that the service is not configured. Do not release this feature as operational until end-to-end verification passes.
