#Создаем VPC с подсетями в разных зонах доступности

resource "yandex_vpc_network" "my_vpc" {
  name = var.VPC_name
}

resource "yandex_vpc_subnet" "public_subnet" {
  count = length(var.public_subnet_zones)
  name  = "${var.public_subnet_name}-${var.public_subnet_zones[count.index]}"
  v4_cidr_blocks = [
    cidrsubnet(var.public_v4_cidr_blocks[0], 4, count.index)
  ]
  zone       = var.public_subnet_zones[count.index]
  network_id = yandex_vpc_network.my_vpc.id
}
