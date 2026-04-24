using CORE.MMms.Interfaces;
using INFRA.MMms.Repository;
using INFRA.MMms.Services;

namespace API.MMms.Resolvers
{
    public static class MotoMasters_Dependencies
    {
        public static void ResolveDependenciesMMs(this IServiceCollection services)
        {
            services.AddTransient<IAppts, ApptsRepo>();
            services.AddTransient<IApptsStatus, ApptsStatusRepo>();
            services.AddTransient<ICategories, CategoriaRepo>();
            services.AddTransient<IClients, ClientsRepo>();
            services.AddTransient<IPData, PDataRepo>();
            services.AddTransient<IProducts, ProductsRepo>();
            services.AddTransient<IServices, ServicesRepo>();
            services.AddTransient<IServicesGiven, ServicesGivenRepo>();
            services.AddTransient<ISoldProducts, SoldProductsRepo>();
            services.AddTransient<IUsers, UsersRepo>();
            services.AddTransient<IUsersType, UsersTypeRepo>();
            services.AddTransient<ISecurity, SecurityRepo>();
            services.AddTransient<ICompras, ComprasRepo>();
            services.AddTransient<IActivos, ActivosRepo>();
            services.AddTransient<IConfiguraciones, ConfiguracionesRepo>();
            services.AddTransient<IProveedores, ProveedoresRepo>();
            services.AddTransient<IFormasPago, FormasPagoRepo>();
            services.AddTransient<IPerfiles, PerfilesRepo>();
            services.AddTransient<IGastos, GastosRepo>();
            services.AddTransient<IAbonos, AbonosRepo>();
            services.AddTransient<ICaja, CajaRepo>();
            services.AddTransient<IReportes, ReportesRepo>();
            services.AddTransient<IPrintService, PrintService>();
            services.AddTransient<IDian, DianRepo>();
            services.AddTransient<IXadesSignerService, XadesSignerService>();
            services.AddTransient<IDianXmlService, DianXmlService>();
            services.AddHttpClient("dian", c => c.Timeout = TimeSpan.FromSeconds(30));
            services.AddTransient<IDianTransmissionService, DianTransmissionService>();
            services.AddTransient<IDianConfig, DianConfigRepo>();
        }
    }
}
