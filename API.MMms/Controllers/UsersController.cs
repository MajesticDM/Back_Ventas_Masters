using AutoMapper;
using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.MMms.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    public class UsersController : ControllerBase
    {
        private readonly IUsers _context;
        private readonly IMapper _mapper;
        private readonly IConfiguration _configuration;
        public UsersController(IUsers context, IMapper mapper, IConfiguration configuration)
        {
            _context = context;
            _mapper = mapper;
            _configuration = configuration;
        }
        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var Users = await _context.GetUsers();
            var User = _mapper.Map<IEnumerable<UsuarioDTOs>>(Users);
            return Ok(User);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int Id)
        {
            var UWU = await _context.GetxId(Id);
            if (UWU == null)
            {
                return Ok(UWU);
            }
            else
            {
                var OWO = _mapper.Map<UsuarioDTOs>(UWU);
                return Ok(OWO);
            }
        }

        [HttpPost]
        public async Task<IActionResult> Save(UsuarioDTOs dTOs)
        {
            var UWU = _mapper.Map<Usuario>(dTOs);
            await _context.Post(UWU);
            return Ok(UWU);
        }
        [HttpPut]
        public async Task<IActionResult> Actualizar(int Id, UsuarioDTOs OWO)
        {
            var UWU = _mapper.Map<Usuario>(OWO);
            UWU.UsuarioId = Id;
            await _context.Update(UWU);
            return Ok(UWU);
        }

        [HttpPost("display")]
        public IActionResult mostrarUsuarios(DatosAccionUsuarios datos)
        {
            var UWU = _context.AccionesUsuarios(datos);
            return Ok(UWU);
        }

        [HttpPost("acciones")]
        public async Task<IActionResult> guardarCliente(IFormFile? image)
        {
            try
            {
                var idPersonal = image.FileName.Split('-')[2];
                DatosAccionUsuarios datos = new DatosAccionUsuarios();

                if (image == null || image.Length == 0)
                    return BadRequest("No image provided");

                var ruta = _configuration.GetValue<string>("RutaGuardarImagenes");
                var rutaServidor = _configuration.GetValue<string>("RutaServidorImagenes");

                var filePath = Path.Combine(ruta, image.FileName + ".png");
                var rutaGuardarDb = Path.Combine(rutaServidor, image.FileName + ".png");

                
                using (var fileStream = new FileStream(filePath, FileMode.Create))
                {
                    await image.CopyToAsync(fileStream);
                }

                _context.guardarRuta(Convert.ToInt32(idPersonal), rutaGuardarDb);


                return Ok();
            }
            catch (Exception ex)
            {

                return Ok(ex);
            }

        }

        [HttpPost("guardarImagen")]
        public async Task<IActionResult> UploadImage(IFormFile image)
        {
            if (image == null || image.Length == 0)
                return BadRequest("No image provided");

            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            var filePath = Path.Combine(uploadsFolder, Guid.NewGuid().ToString() + Path.GetExtension(image.FileName));

            using (var fileStream = new FileStream(filePath, FileMode.Create))
            {
                await image.CopyToAsync(fileStream);
            }

            return Ok(new { filePath });
        }
    }
}
