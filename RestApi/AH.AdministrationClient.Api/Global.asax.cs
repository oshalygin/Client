using System.Web.Http;

namespace AH.AdministrationClient.Api
{
    public class WebApiApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);   
        }
    }
}
