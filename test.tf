
#############################################################################################################
#############################################################################################################

variable "api_name" {
  
  default = "Test-api"
}

variable "dynamic_paths" {
   type = list(string)
 #default = ["ondot-mcs", "ondot-cm", "ondot-tde", "ondot-cas"]
}

variable "dynamic_path2" {
   type = list(string)
 #default = ["v1", "v2", "v3", "v4"]
}

variable "nested_subpaths" {
   type = list(list(string))
#  default = [
#     ["Subpath1_1", "Subpath1_2", "Subpath1_3","Subpath1_4"],
#     ["Subpath2_1", "Subpath2_2", "Subpath2_3"],
#     ["Subpath3_1", "Subpath3_2", "Subpath3_3"],
#     ["Subpath4_1", "Subpath4_2"],
#      #["bidya", "rajat", "naveen"]
#   ]
}

resource "aws_api_gateway_rest_api" "example" {
  name        = var.api_name
  description = "Name of the API"
}

resource "aws_api_gateway_resource" "dynamic" {
  count       = length(var.dynamic_paths)
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = var.dynamic_paths[count.index]
}

resource "aws_api_gateway_resource" "dynamic2" {
  count       = length(var.dynamic_path2)
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.dynamic[count.index % length(var.dynamic_paths)].id
  path_part   = var.dynamic_path2[count.index]
}

locals {
  nested_resources = flatten([
    for idx, subpaths in var.nested_subpaths : [
      for subpath in subpaths : {
        parent_id = aws_api_gateway_resource.dynamic2[idx].id
         #path_part = "${var.dynamic_paths[idx]}${var.dynamic_path2[idx]}${subpath}"
         path_part = "${subpath}"
        #path_part = "${var.dynamic_path2[idx]}${subpath}"
      }
    ]
  ])
}

resource "aws_api_gateway_resource" "nested" {
  count       = length(local.nested_resources)
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = local.nested_resources[count.index].parent_id
  path_part   = local.nested_resources[count.index].path_part

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "example" {
  count         = length(local.nested_resources)
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.nested[count.index].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example" {
  count                     = length(local.nested_resources)
  rest_api_id               = aws_api_gateway_rest_api.example.id
  resource_id               = aws_api_gateway_resource.nested[count.index].id
  http_method               = aws_api_gateway_method.example[count.index].http_method
  integration_http_method   = "POST"
  type                      = "MOCK"
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  triggers = {
    redeployment = sha1(jsonencode([
#       aws_api_gateway_resource.dynamic[*].id,
#       aws_api_gateway_resource.dynamic2[*].id,
#       aws_api_gateway_resource.nested[*].id,
      aws_api_gateway_method.example[*].id,
      aws_api_gateway_integration.example[*].id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "rest_api_stage"
}

##################################################################################

