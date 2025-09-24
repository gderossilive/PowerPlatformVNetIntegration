@description('API Management service name')
param apimName string

@description('APIM user name (unique within the APIM instance)')
param userName string

@description('User display first name')
param firstName string = userName

@description('User display last name')
param lastName string = userName

@description('User email address')
param email string

@description('User state')
@allowed([
  'active'
  'blocked'
])
param state string = 'active'

resource apimUser 'Microsoft.ApiManagement/service/users@2022-08-01' = {
  name: '${apimName}/${userName}'
  properties: {
    firstName: firstName
    lastName: lastName
    email: email
    state: state
  }
}

output userId string = apimUser.id
output name string = userName
