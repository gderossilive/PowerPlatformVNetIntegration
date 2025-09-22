# Petstore Azure Functions API

This is an Azure Functions implementation of the Swagger Petstore OpenAPI 3.0 specification. It provides a complete REST API scaffold for managing pets, store orders, and users.

## Features

- **Complete OpenAPI 3.0 Implementation**: All endpoints from the Swagger Petstore specification
- **VNet Integration**: Deployed within Azure Virtual Network for security
- **Application Insights**: Full monitoring and logging capabilities
- **CORS Enabled**: Ready for cross-origin requests
- **Health Check**: Built-in health monitoring endpoint

## API Endpoints

### Pet Operations
- `POST /api/v3/pet` - Add a new pet to the store
- `PUT /api/v3/pet` - Update an existing pet
- `GET /api/v3/pet/findByStatus` - Find pets by status
- `GET /api/v3/pet/findByTags` - Find pets by tags
- `GET /api/v3/pet/{petId}` - Find pet by ID
- `POST /api/v3/pet/{petId}` - Update pet with form data
- `DELETE /api/v3/pet/{petId}` - Delete a pet

### Store Operations
- `GET /api/v3/store/inventory` - Get pet inventories by status
- `POST /api/v3/store/order` - Place an order for a pet
- `GET /api/v3/store/order/{orderId}` - Find purchase order by ID
- `DELETE /api/v3/store/order/{orderId}` - Delete purchase order

### User Operations
- `POST /api/v3/user` - Create user
- `POST /api/v3/user/createWithList` - Create list of users
- `GET /api/v3/user/login` - Log user into the system
- `GET /api/v3/user/logout` - Log out current user session
- `GET /api/v3/user/{username}` - Get user by username
- `PUT /api/v3/user/{username}` - Update user
- `DELETE /api/v3/user/{username}` - Delete user

### Utility Endpoints
- `GET /api/v3/openapi.json` - OpenAPI specification
- `GET /health` - Health check endpoint

## Infrastructure

The Azure Functions app is deployed with:

- **App Service Plan**: Consumption (Y1) for automatic scaling
- **Storage Account**: Required for Azure Functions runtime
- **Application Insights**: For monitoring and logging
- **VNet Integration**: Connected to private endpoint subnet
- **CORS**: Enabled for all origins (configurable)

## Sample Data

The API comes with sample data for testing:

- **Pets**: Buddy (Dog) and Whiskers (Cat)
- **Users**: John Doe (user1)
- **Orders**: Sample order for pet #1

## Testing

You can test the API using:

```bash
# Get all available pets
curl https://{function-app-name}.azurewebsites.net/api/v3/pet/findByStatus?status=available

# Get pet by ID
curl https://{function-app-name}.azurewebsites.net/api/v3/pet/1

# Health check
curl https://{function-app-name}.azurewebsites.net/health

# OpenAPI specification
curl https://{function-app-name}.azurewebsites.net/api/v3/openapi.json
```

## Integration with API Management

This Function App is designed to work seamlessly with Azure API Management (APIM) for:

- API versioning and lifecycle management
- Security policies and authentication
- Rate limiting and throttling
- API documentation and developer portal
- Backend service abstraction

## Development

To develop locally:

1. Install Azure Functions Core Tools
2. Install dependencies: `npm install`
3. Start local development: `func start`

## Deployment

The Function App is automatically deployed via Bicep templates as part of the Power Platform VNet Integration infrastructure.

## Monitoring

Application Insights provides:

- Request/response tracking
- Performance metrics
- Error monitoring
- Custom telemetry
- Live metrics stream

Access monitoring through the Azure portal or Application Insights dashboard.
