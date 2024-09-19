const AmazonCognitoIdentity = require("amazon-cognito-identity-js");
const AWS = require("aws-sdk");

// Configurações Cognito usando as variáveis de output geradas pelo Terraform
const cognitoConfig = {
  UserPoolId: process.env.COGNITO_USER_POOL_ID, // Setado nas variáveis de ambiente da Lambda
  ClientId: process.env.COGNITO_CLIENT_ID, // Setado nas variáveis de ambiente da Lambda
};

// Função para autenticar o usuário com CPF e senha
async function authenticateUser(cpf, password) {
  const userPool = new AmazonCognitoIdentity.CognitoUserPool(cognitoConfig);

  const userData = {
    Username: cpf, // O CPF é usado como nome de usuário
    Pool: userPool,
  };

  const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails(
    {
      Username: cpf,
      Password: password,
    }
  );

  const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

  return new Promise((resolve, reject) => {
    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: (result) => {
        // Retorna o token JWT
        resolve({
          idToken: result.getIdToken().getJwtToken(),
          accessToken: result.getAccessToken().getJwtToken(),
          refreshToken: result.getRefreshToken().getToken(),
        });
      },
      onFailure: (err) => {
        reject(err);
      },
    });
  });
}

// Handler da Lambda para processar a autenticação via API Gateway
exports.handler = async (event) => {
  try {
    const { cpf, password } = JSON.parse(event.body);

    // Chama a função para autenticar o usuário
    const tokens = await authenticateUser(cpf, password);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Autenticação bem-sucedida!",
        tokens: tokens,
      }),
    };
  } catch (err) {
    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "Erro de autenticação",
        error: err.message,
      }),
    };
  }
};
