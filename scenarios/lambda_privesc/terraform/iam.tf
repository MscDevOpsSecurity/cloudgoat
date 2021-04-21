#IAM User
resource "aws_iam_user" "cg-chris" {
  name = "chris-${var.cgid}"
  force_destroy = true  # just in case
  tags = {
    Name     = "cg-chris-${var.cgid}"
    Stack    = "var.stack-name"
    Scenario = "var.scenario-name"
  }
}

# IAM Console access
 
resource "local_file" "key_gen_template" {
    content  = <<EOF
%no-protection
Key-Type:1
Key-Length:2048
Subkey-Type:1
Subkey-Length:2048
Name-Real: ${aws_iam_user.cg-chris.name}
Name-Email: ${aws_iam_user.cg-chris.name}
Expire-Date:0
EOF
    filename = "key-gen-template"
}

resource "null_resource" "gpg_key" {
  provisioner "local-exec" {
    command = "gpg -k && gpg --batch --gen-key key-gen-template && gpg --output public-key.gpg --export ${aws_iam_user.cg-chris.name}"
  }
  depends_on = [local_file.key_gen_template]
}

data "local_file" "pgp_key" {
  filename = "public-key.gpg"
  depends_on = [null_resource.gpg_key]
}

resource "aws_iam_user_login_profile" "cg-chris" {
  user    = aws_iam_user.cg-chris.name
  pgp_key = data.local_file.pgp_key.content_base64
  #file("public-key.gpg").content_base64
  #data.local_file.pgp_key.content_base64
  depends_on = [
    data.local_file.pgp_key
  ]
}


resource "aws_iam_access_key" "cg-chris" {
  user = aws_iam_user.cg-chris.name
}

# IAM roles
resource "aws_iam_role" "cg-lambdaManager-role" {
  name = "cg-lambdaManager-role-${var.cgid}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "${aws_iam_user.cg-chris.arn}"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "cg-debug-role-${var.cgid}"
    Stack = "var.stack-name"
    Scenario = "var.scenario-name"
  }
}

resource "aws_iam_role" "cg-debug-role" {
  name = "cg-debug-role-${var.cgid}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "cg-debug-role-${var.cgid}"
    Stack = "var.stack-name"
    Scenario = "var.scenario-name"
  }
}

# IAM Policies
resource "aws_iam_policy" "cg-lambdaManager-policy" {
  name = "cg-lambdaManager-policy-${var.cgid}"
  description = "cg-lambdaManager-policy-${var.cgid}"
  policy =<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "lambdaManager",
            "Effect": "Allow",
            "Action": [
                "lambda:*",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "cg-chris-policy" {
  name = "cg-chris-policy-${var.cgid}"
  description = "cg-chris-policy-${var.cgid}"
  policy =<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "chris",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole",
                "iam:List*",
                "iam:Get*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

#Policy Attachments
resource "aws_iam_role_policy_attachment" "cg-debug-role-attachment" {
  role = aws_iam_role.cg-debug-role.name
  policy_arn = data.aws_iam_policy.administrator-full-access.arn
}

resource "aws_iam_role_policy_attachment" "cg-lambdaManager-role-attachment" {
  role = aws_iam_role.cg-lambdaManager-role.name
  policy_arn = aws_iam_policy.cg-lambdaManager-policy.arn
}

resource "aws_iam_user_policy_attachment" "cg-chris-attachment" {
  user = aws_iam_user.cg-chris.name
  policy_arn = aws_iam_policy.cg-chris-policy.arn
}