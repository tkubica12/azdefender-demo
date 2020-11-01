﻿using Microsoft.Owin;
using Owin;
using Microsoft.SqlServer.Management.AlwaysEncrypted.AzureKeyVaultProvider;
using System.Collections.Generic;
using System.Data.SqlClient;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using System;

[assembly: OwinStartupAttribute(typeof(ContosoClinic.Startup))]
namespace ContosoClinic
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
			ConfigureAuth(app);
			InitializeAzureKeyVaultProvider();
		}

        private static Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential _clientCredential;

        static void InitializeAzureKeyVaultProvider()
        {
            string clientId = Environment.GetEnvironmentVariable("CLIENT_ID");
            string clientSecret = Environment.GetEnvironmentVariable("CLIENT_SECRET");

            _clientCredential = new ClientCredential(clientId, clientSecret);

           SqlColumnEncryptionAzureKeyVaultProvider azureKeyVaultProvider =
              new SqlColumnEncryptionAzureKeyVaultProvider(GetToken);

            Dictionary<string, SqlColumnEncryptionKeyStoreProvider> providers =
              new Dictionary<string, SqlColumnEncryptionKeyStoreProvider>();

            providers.Add(SqlColumnEncryptionAzureKeyVaultProvider.ProviderName, azureKeyVaultProvider);
            SqlConnection.RegisterColumnEncryptionKeyStoreProviders(providers);
        }

        public async static System.Threading.Tasks.Task<string> GetToken(string authority, string resource, string scope)
        {
            var authContext = new AuthenticationContext(authority);
            AuthenticationResult result = await authContext.AcquireTokenAsync(resource, _clientCredential);

            if (result == null)
                throw new System.InvalidOperationException("Failed to obtain the access token");

            return result.AccessToken;
        }
    }
}