const { app } = require('@azure/functions');

// Sample data for demonstration
const pets = [
  {
    id: 1,
    name: "Buddy",
    category: { id: 1, name: "Dogs" },
    photoUrls: ["https://example.com/buddy.jpg"],
    tags: [{ id: 1, name: "friendly" }],
    status: "available"
  },
  {
    id: 2,
    name: "Whiskers",
    category: { id: 2, name: "Cats" },
    photoUrls: ["https://example.com/whiskers.jpg"],
    tags: [{ id: 2, name: "playful" }],
    status: "available"
  }
];

const users = [
  {
    id: 1,
    username: "user1",
    firstName: "John",
    lastName: "Doe",
    email: "john@example.com",
    password: "password123",
    phone: "123-456-7890",
    userStatus: 1
  }
];

const orders = [
  {
    id: 1,
    petId: 1,
    quantity: 1,
    shipDate: new Date().toISOString(),
    status: "placed",
    complete: false
  }
];

// Pet endpoints
app.http('addPet', {
  methods: ['POST'],
  route: 'api/v3/pet',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const newPet = await request.json();
      newPet.id = pets.length + 1;
      pets.push(newPet);
      
      context.log('Pet added:', newPet);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newPet)
      };
    } catch (error) {
      context.log.error('Error adding pet:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid input' })
      };
    }
  }
});

app.http('updatePet', {
  methods: ['PUT'],
  route: 'api/v3/pet',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const updatedPet = await request.json();
      const index = pets.findIndex(p => p.id == updatedPet.id);
      
      if (index === -1) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Pet not found' })
        };
      }
      
      pets[index] = { ...pets[index], ...updatedPet };
      
      context.log('Pet updated:', pets[index]);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(pets[index])
      };
    } catch (error) {
      context.log.error('Error updating pet:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid ID supplied' })
      };
    }
  }
});

app.http('findPetsByStatus', {
  methods: ['GET'],
  route: 'api/v3/pet/findByStatus',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const status = request.query.get('status') || 'available';
      const filteredPets = pets.filter(pet => pet.status === status);
      
      context.log('Finding pets by status:', status);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(filteredPets)
      };
    } catch (error) {
      context.log.error('Error finding pets by status:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid status value' })
      };
    }
  }
});

app.http('findPetsByTags', {
  methods: ['GET'],
  route: 'api/v3/pet/findByTags',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const tags = request.query.get('tags');
      if (!tags) {
        return {
          status: 400,
          body: JSON.stringify({ error: 'Tags parameter is required' })
        };
      }
      
      const tagArray = tags.split(',');
      const filteredPets = pets.filter(pet => 
        pet.tags && pet.tags.some(tag => tagArray.includes(tag.name))
      );
      
      context.log('Finding pets by tags:', tagArray);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(filteredPets)
      };
    } catch (error) {
      context.log.error('Error finding pets by tags:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid tag value' })
      };
    }
  }
});

app.http('getPetById', {
  methods: ['GET'],
  route: 'api/v3/pet/{petId}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const petId = parseInt(request.params.petId);
      const pet = pets.find(p => p.id === petId);
      
      if (!pet) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Pet not found' })
        };
      }
      
      context.log('Getting pet by ID:', petId);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(pet)
      };
    } catch (error) {
      context.log.error('Error getting pet by ID:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid ID supplied' })
      };
    }
  }
});

app.http('updatePetWithForm', {
  methods: ['POST'],
  route: 'api/v3/pet/{petId}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const petId = parseInt(request.params.petId);
      const pet = pets.find(p => p.id === petId);
      
      if (!pet) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Pet not found' })
        };
      }
      
      const name = request.query.get('name');
      const status = request.query.get('status');
      
      if (name) pet.name = name;
      if (status) pet.status = status;
      
      context.log('Updated pet with form data:', pet);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(pet)
      };
    } catch (error) {
      context.log.error('Error updating pet with form:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid input' })
      };
    }
  }
});

app.http('deletePet', {
  methods: ['DELETE'],
  route: 'api/v3/pet/{petId}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const petId = parseInt(request.params.petId);
      const index = pets.findIndex(p => p.id === petId);
      
      if (index === -1) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Pet not found' })
        };
      }
      
      pets.splice(index, 1);
      
      context.log('Deleted pet with ID:', petId);
      return {
        status: 200,
        body: 'Pet deleted'
      };
    } catch (error) {
      context.log.error('Error deleting pet:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid pet value' })
      };
    }
  }
});

// Store endpoints
app.http('getInventory', {
  methods: ['GET'],
  route: 'api/v3/store/inventory',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const inventory = pets.reduce((acc, pet) => {
        acc[pet.status] = (acc[pet.status] || 0) + 1;
        return acc;
      }, {});
      
      context.log('Getting inventory');
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(inventory)
      };
    } catch (error) {
      context.log.error('Error getting inventory:', error);
      return {
        status: 500,
        body: JSON.stringify({ error: 'Internal server error' })
      };
    }
  }
});

app.http('placeOrder', {
  methods: ['POST'],
  route: 'api/v3/store/order',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const newOrder = await request.json();
      newOrder.id = orders.length + 1;
      newOrder.shipDate = new Date().toISOString();
      orders.push(newOrder);
      
      context.log('Order placed:', newOrder);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newOrder)
      };
    } catch (error) {
      context.log.error('Error placing order:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid input' })
      };
    }
  }
});

app.http('getOrderById', {
  methods: ['GET'],
  route: 'api/v3/store/order/{orderId}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const orderId = parseInt(request.params.orderId);
      const order = orders.find(o => o.id === orderId);
      
      if (!order) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Order not found' })
        };
      }
      
      context.log('Getting order by ID:', orderId);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(order)
      };
    } catch (error) {
      context.log.error('Error getting order by ID:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid ID supplied' })
      };
    }
  }
});

app.http('deleteOrder', {
  methods: ['DELETE'],
  route: 'api/v3/store/order/{orderId}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const orderId = parseInt(request.params.orderId);
      const index = orders.findIndex(o => o.id === orderId);
      
      if (index === -1) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'Order not found' })
        };
      }
      
      orders.splice(index, 1);
      
      context.log('Deleted order with ID:', orderId);
      return {
        status: 200,
        body: 'Order deleted'
      };
    } catch (error) {
      context.log.error('Error deleting order:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid ID supplied' })
      };
    }
  }
});

// User endpoints
app.http('createUser', {
  methods: ['POST'],
  route: 'api/v3/user',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const newUser = await request.json();
      newUser.id = users.length + 1;
      users.push(newUser);
      
      context.log('User created:', { id: newUser.id, username: newUser.username });
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newUser)
      };
    } catch (error) {
      context.log.error('Error creating user:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid input' })
      };
    }
  }
});

app.http('createUsersWithListInput', {
  methods: ['POST'],
  route: 'api/v3/user/createWithList',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const userList = await request.json();
      const createdUsers = [];
      
      userList.forEach(user => {
        user.id = users.length + 1;
        users.push(user);
        createdUsers.push(user);
      });
      
      context.log('Users created:', createdUsers.length);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(createdUsers[0] || {}) // Return first user as per API spec
      };
    } catch (error) {
      context.log.error('Error creating users with list:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid input' })
      };
    }
  }
});

app.http('loginUser', {
  methods: ['GET'],
  route: 'api/v3/user/login',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const username = request.query.get('username');
      const password = request.query.get('password');
      
      const user = users.find(u => u.username === username && u.password === password);
      
      if (!user) {
        return {
          status: 400,
          body: JSON.stringify({ error: 'Invalid username/password supplied' })
        };
      }
      
      const token = `session_${Date.now()}_${user.id}`;
      const expiresAfter = new Date(Date.now() + 3600000).toISOString(); // 1 hour
      
      context.log('User logged in:', username);
      return {
        status: 200,
        headers: {
          'Content-Type': 'text/plain',
          'X-Rate-Limit': '5000',
          'X-Expires-After': expiresAfter
        },
        body: token
      };
    } catch (error) {
      context.log.error('Error logging in user:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid username/password supplied' })
      };
    }
  }
});

app.http('logoutUser', {
  methods: ['GET'],
  route: 'api/v3/user/logout',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    context.log('User logged out');
    return {
      status: 200,
      body: 'Successful operation'
    };
  }
});

app.http('getUserByName', {
  methods: ['GET'],
  route: 'api/v3/user/{username}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const username = request.params.username;
      const user = users.find(u => u.username === username);
      
      if (!user) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'User not found' })
        };
      }
      
      context.log('Getting user by name:', username);
      return {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(user)
      };
    } catch (error) {
      context.log.error('Error getting user by name:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid username supplied' })
      };
    }
  }
});

app.http('updateUser', {
  methods: ['PUT'],
  route: 'api/v3/user/{username}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const username = request.params.username;
      const updatedUser = await request.json();
      const index = users.findIndex(u => u.username === username);
      
      if (index === -1) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'User not found' })
        };
      }
      
      users[index] = { ...users[index], ...updatedUser };
      
      context.log('User updated:', username);
      return {
        status: 200,
        body: 'Successful operation'
      };
    } catch (error) {
      context.log.error('Error updating user:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Bad request' })
      };
    }
  }
});

app.http('deleteUser', {
  methods: ['DELETE'],
  route: 'api/v3/user/{username}',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    try {
      const username = request.params.username;
      const index = users.findIndex(u => u.username === username);
      
      if (index === -1) {
        return {
          status: 404,
          body: JSON.stringify({ error: 'User not found' })
        };
      }
      
      users.splice(index, 1);
      
      context.log('User deleted:', username);
      return {
        status: 200,
        body: 'User deleted'
      };
    } catch (error) {
      context.log.error('Error deleting user:', error);
      return {
        status: 400,
        body: JSON.stringify({ error: 'Invalid username supplied' })
      };
    }
  }
});

// OpenAPI specification endpoint
app.http('openapi', {
  methods: ['GET'],
  route: 'api/v3/openapi.json',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    const openApiSpec = {
      openapi: "3.0.4",
      info: {
        title: "Swagger Petstore - OpenAPI 3.0 (Azure Functions)",
        description: "This is a sample Pet Store Server implemented using Azure Functions, based on the OpenAPI 3.0 specification.",
        termsOfService: "https://swagger.io/terms/",
        contact: {
          email: "apiteam@swagger.io"
        },
        license: {
          name: "Apache 2.0",
          url: "https://www.apache.org/licenses/LICENSE-2.0.html"
        },
        version: "1.0.27"
      },
      externalDocs: {
        description: "Find out more about Swagger",
        url: "https://swagger.io"
      },
      servers: [
        {
          url: "/api/v3"
        }
      ],
      tags: [
        {
          name: "pet",
          description: "Everything about your Pets",
          externalDocs: {
            description: "Find out more",
            url: "https://swagger.io"
          }
        },
        {
          name: "store",
          description: "Access to Petstore orders"
        },
        {
          name: "user",
          description: "Operations about user"
        }
      ],
      paths: {
        "/pet": {
          put: {
            tags: ["pet"],
            summary: "Update an existing pet",
            description: "Update an existing pet by Id",
            operationId: "updatePet",
            responses: {
              "200": {
                description: "Successful operation"
              },
              "400": {
                description: "Invalid ID supplied"
              },
              "404": {
                description: "Pet not found"
              },
              "422": {
                description: "Validation exception"
              }
            }
          },
          post: {
            tags: ["pet"],
            summary: "Add a new pet to the store",
            description: "Add a new pet to the store",
            operationId: "addPet",
            responses: {
              "200": {
                description: "Successful operation"
              },
              "400": {
                description: "Invalid input"
              },
              "422": {
                description: "Validation exception"
              }
            }
          }
        }
        // Additional paths would be defined here for full compliance
      }
    };
    
    context.log('Serving OpenAPI specification');
    return {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(openApiSpec, null, 2)
    };
  }
});

// Health check endpoint
app.http('health', {
  methods: ['GET'],
  route: 'health',
  authLevel: 'anonymous',
  handler: async (request, context) => {
    context.log('Health check requested');
    return {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'Petstore API (Azure Functions)',
        version: '1.0.27'
      })
    };
  }
});
