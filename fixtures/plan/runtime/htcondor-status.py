import htcondor
schedd = htcondor.Schedd()
projection = ["ClusterId", "ProcId", "JobStatus", "Cmd", "User"]
