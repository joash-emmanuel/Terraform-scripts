#sts assume role policy for the cluster role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# EKS Cluster IAM Role and attatch sts assume role
resource "aws_iam_role" "EKSclusterrole2" {
  name               = "EKSclusterrole2"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


#Attatch the policy to the cluster role
resource "aws_iam_role_policy_attachment" "EKS_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EKSclusterrole2.name
}

#Attatch the policy to the cluster role
resource "aws_iam_role_policy_attachment" "EKS_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.EKSclusterrole2.name
}

#Attatch the policy to the cluster role
resource "aws_iam_role_policy_attachment" "EKS_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.EKSclusterrole2.name
}

#create a cluster
resource "aws_eks_cluster" "cluster-1" {
  name     = "cluster-1"
  role_arn = aws_iam_role.EKSclusterrole2.arn
  version  = "1.25"

  vpc_config {
    security_group_ids      = [aws_security_group.dev_security_group.id]
    subnet_ids              =  flatten([aws_subnet.dev_public_subnet[*].id, aws_subnet.dev_private_subnet[*].id])
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }


  depends_on = [
    aws_iam_role_policy_attachment.EKS_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.EKS_AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.EKS_CloudWatchAgentServerPolicy,
  ]
}
      #worker nodes

#creating a worker node role
resource "aws_iam_role" "workernoderole2" {
  name = "workernoderole2"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

#create a policy
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernoderole2.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernoderole2.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernoderole2.name
}

#node group creation
resource "aws_eks_node_group" "node-group-1" {
  cluster_name    = aws_eks_cluster.cluster-1.name
  node_group_name = "node-group-1"
  node_role_arn   = aws_iam_role.workernoderole2.arn
  subnet_ids      = aws_subnet.dev_private_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 20
  instance_types = ["t2.medium"]


  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

  #fargate class 
#create a fargate role
resource "aws_iam_role" "EKSfargaterole2" {
  name = "EKSfargaterole2"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

#Create a policy and attatch to the fargate role
resource "aws_iam_role_policy_attachment" "fargate-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.EKSfargaterole2.name
}

resource "aws_eks_fargate_profile" "profile-A" {
  cluster_name           = aws_eks_cluster.cluster-1.name
  fargate_profile_name   = "profile-A"
  pod_execution_role_arn = aws_iam_role.EKSfargaterole2.arn
  subnet_ids             = aws_subnet.dev_private_subnet[*].id

  selector {
    namespace = "dev"
  }
}
