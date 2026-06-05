job "batch-demo" {
  datacenters = ["dc1"]
  type = "batch"
  group "workers" {
    task "worker" {
      driver = "docker"
      config { image = "example/worker:latest" }
      resources { cpu = 500 memory = 256 }
    }
  }
}
