using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IServicesGiven
    {
        Task<IEnumerable<Factura>> GetServicesGiven();
        Task<Factura> GetxId(int Id);
        Task Post(ServiciosDado MMD);
        Task<bool> Update(int id, bool estado);
        string crearFacturaServiciosProductos(Venta venta);
        DataSet SelectFacturas(bool todas, decimal cliente, decimal usuario, string fechaInicial, string fechaFinal, bool soloAnuladas);
        DataSet SelectCompras(bool todas, decimal proveedor, decimal usuario, string fechaInicial, string fechaFinal);
        bool AnularFactura(decimal idFactura);
    }
}
