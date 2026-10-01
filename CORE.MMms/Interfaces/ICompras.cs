using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface ICompras
    {
        Task<IEnumerable<Compra>> GetCompras();
        Task<Compra> GetxId(int Id);
        Task Post(Compra MMD);
        string generarCompra(CompraDTO cuerpoCompra);
        DataTable cargarComprasParaSelect();
        void AnularCompra(int idCompra, int idUsuario);
    }
}
