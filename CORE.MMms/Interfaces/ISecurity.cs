using CORE.MMms.Entidades;

namespace CORE.MMms.Interfaces
{
    public interface ISecurity
    {
        Task<Usuario> GetLoginByCredential(Security login);
    }
}
