# Generate schematic from Image Factory
data "http" "image_factory_schematic" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    customization = merge(
      {
        systemExtensions = {
          officialExtensions = var.extensions
        }
      },
      length(var.kernel_args) > 0 ? {
        extraKernelArgs = var.kernel_args
      } : {}
    )
  })
}

locals {
  schematic_id = jsondecode(data.http.image_factory_schematic.response_body).id
  image_url    = "https://factory.talos.dev/image/${local.schematic_id}/${var.talos_version}/${var.platform}-${var.architecture}.raw.xz"
}
