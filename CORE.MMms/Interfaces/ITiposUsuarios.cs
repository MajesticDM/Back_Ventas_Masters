using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface IUsersType
    {
        Task<IEnumerable<UsuariosTipo>> GetUsersType();
        Task<UsuariosTipo> GetxId(int Id);
        Task Post(UsuariosTipo MMD);
        Task<bool> Update(UsuariosTipo MMD);
        Task<bool> Delete(int Id);
    }
}
