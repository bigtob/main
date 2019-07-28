# Account details
tenantid = ""
subscriptionid = ""

# Terraform service principal
clientid = ""
clientsecret = ""

# Project specific variables
service = ""
env = ""
versionno = ""
instanceno = ""
location = ""
rhelversion = ""
vnetname = ""
subnetname = ""
directorate = ""
subdirectorate = ""
costcentre = ""
projectcode = ""
irnumber = ""
supportteam1 = ""
supportteam2 = ""
servicehours = ""
lifecyclestatus = ""
stgtier = ""

# Prod host number list: 158 159 160 161 162 163 164 165 166 167 168 169 170 171 172 173 174

# List variables
vmsizelist = ["Standard_D4s_v3", "Standard_D8s_v3", "Standard_D16s_v3"]

# Servers required
# Smallworld Replica Datasets Server   - RHEL - 1 - Standard_D8s_v3  - stg 
# Mobile Reverse Proxy Server NGINX    - RHEL - 2 - Standard_D4s_v3  - stg - AVSET
# Couchbase Sync Gateway               - RHEL - 2 - Standard_D4s_v3  - stg - AVSET
# Couchbase Server                     - RHEL - 3 - Standard_D4s_v3  - stg - AVSET
# Oracle DB Server                     - RHEL - 2 - Standard_D4s_v3  - stg - AVSET

# Smallworld EIS server                - WIN  - 2 - Standard_D16s_v3 - stg - AVSET
# Smallworld EO Web Application Server - WIN  - 1 - Standard_D4s_v3  - stg
# Mobility Server                      - WIN  - 4 - Standard_D8s_v3  - stg - AVSET

#                          7xWIN 10xRHEL       17