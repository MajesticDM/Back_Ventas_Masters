using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace INFRA.MMms.Mapping
{
    public class Mapping : Profile
    {
        public Mapping()
        {
            CreateMap<Cita, CitaDTOs>();
            CreateMap<CitaDTOs, Cita>();

            CreateMap<CitasEstado, CitasEstadoDTOs>();
            CreateMap<CitasEstadoDTOs, CitasEstado>();

            CreateMap<Categoria, CategoriaDTOs>();
            CreateMap<CategoriaDTOs, Categoria>();

            CreateMap<Cliente, ClienteDTOs>();
            CreateMap<ClienteDTOs, Cliente>();

            CreateMap<DatosPersonale, DatosPersonaleDTOs>();
            CreateMap<DatosPersonaleDTOs, DatosPersonale>();

            CreateMap<Producto, ProductoDTOs>();
            CreateMap<ProductoDTOs, Producto>();

            CreateMap<Servicio, ServicioDTOs>();
            CreateMap<ServicioDTOs, Servicio>();

            CreateMap<ServiciosDado, ServiciosDadoDTOs>();
            CreateMap<ServiciosDadoDTOs, ServiciosDado>();

            CreateMap<VendidoProducto, VendidoProductoDTOs>();
            CreateMap<VendidoProductoDTOs, VendidoProducto>();

            CreateMap<Usuario, UsuarioDTOs>();
            CreateMap<UsuarioDTOs, Usuario>();

            CreateMap<UsuariosTipo, UsuariosTipoDTOs>();
            CreateMap<UsuariosTipoDTOs, UsuariosTipo>();

            CreateMap<Compra, CompraDTO>();
            CreateMap<CompraDTO, Compra>();
            
            CreateMap<Activo, ActivosDTOs>();
            CreateMap<ActivosDTOs, Activo>();
        }
    }
}
