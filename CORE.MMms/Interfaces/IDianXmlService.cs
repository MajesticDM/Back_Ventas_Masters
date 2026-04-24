using CORE.MMms.DTOs;

namespace CORE.MMms.Interfaces
{
    public interface IDianXmlService
    {
        DianGenerarXmlResultDto GenerarXml(long idFactura);
    }
}
