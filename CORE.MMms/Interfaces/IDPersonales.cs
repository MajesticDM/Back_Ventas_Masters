using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface IPData
    {
        Task<IEnumerable<DatosPersonale>> GetPData();
        Task<DatosPersonale> GetxId(int Id);
        Task Post(DatosPersonale MMD);
        Task<bool> Update(DatosPersonale MMD);
        Task<bool> Delete(int Id);
    }
}
