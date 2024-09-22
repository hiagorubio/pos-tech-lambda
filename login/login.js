const {
  CognitoIdentityProviderClient,
  SignUpCommand,
  InitiateAuthCommand,
} = require("@aws-sdk/client-cognito-identity-provider");

const signUpUser = async (username, name, password, cpf) => {
  const client = new CognitoIdentityProviderClient({ region: "us-east-1" });
  const command = new SignUpCommand({
    ClientId: process.env.COGNITO_CLIENT_ID,
    Username: username,
    Password: password,
    UserAttributes: [
      {
        Name: "email",
        Value: username,
      },
      {
        Name: "name",
        Value: name,
      },
      {
        Name: "custom:cpf",
        Value: cpf,
      },
    ],
  });

  try {
    const response = await client.send(command);
    return response;
  } catch (error) {
    console.error("Erro ao registrar usuário:", error);
  }
};

async function registerUser(event) {
  const { username, name, password, cpf } = JSON.parse(event.body);
  console.log("registerUser username", username);
  try {
    await signUpUser(username, name, password, cpf);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Usuário registrado com sucesso",
      }),
    };
  } catch (error) {
    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "Erro ao registrar usuário",
        error: error.message,
      }),
    };
  }
}

async function loginUser(event) {
  const { username, password } = JSON.parse(event.body);

  const client = new CognitoIdentityProviderClient({ region: "us-east-1" });
  const command = new InitiateAuthCommand({
    AuthFlow: "USER_PASSWORD_AUTH",
    ClientId: process.env.COGNITO_CLIENT_ID,
    AuthParameters: {
      USERNAME: username,
      PASSWORD: password,
    },
  });

  try {
    const response = await client.send(command);
    console.log("Login bem-sucedido:", response);
    if (response?.AuthenticationResult?.AccessToken) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: "Usuário autenticado com sucesso",
          response: response?.AuthenticationResult?.AccessToken,
        }),
      };
    }
    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "Erro ao autenticar usuário",
      }),
    };
  } catch (error) {
    console.error("Erro ao fazer login:", error);
    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "Erro ao autenticar usuário",
        error: error.message,
      }),
    };
  }
}

exports.handler = async (event) => {
  console.log("event", event);
  const path = event.resource;
  console.log("path", path);
  const httpMethod = event.httpMethod;
  console.log("httpMethod", httpMethod);

  if (path === "/auth/register" && httpMethod === "POST") {
    return await registerUser(event);
  } else if (path === "/auth/login" && httpMethod === "POST") {
    return await loginUser(event);
  } else {
    return {
      statusCode: 404,
      body: JSON.stringify({ message: "Not found" }),
    };
  }
};
