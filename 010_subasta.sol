// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Subasta - Contrato de subasta pública con reglas avanzadas
/// Permite subastas con incrementos mínimos, extensión de tiempo, reembolsos parciales y comisión
contract Subasta {
    // Estructuras y Variables ---
    struct Oferta {
        uint256 monto;
        uint256 timestamp;
    }

    struct Item {
        string nombre;
        string descripcion;
    }

    address payable public immutable beneficiario;
    Item public item;
    uint256 public immutable tiempoInicial;
    uint256 public tiempoFin;
    bool public finalizada;
    uint256 public constanteComision = 200; // 2% (en basis points, 10000 = 100%)
    uint256 public constanteIncremento = 500; // 5% (en basis points)
    uint256 public extensionTiempo = 10 minutes;

    address public ganador;
    uint256 public ofertaGanadora;

    // Historial de ofertas por usuario
    mapping(address => Oferta[]) public historialOfertas;
    // Total depositado por usuario
    mapping(address => uint256) public depositos;
    // Lista de oferentes únicos
    address[] public oferentes;

    // --- Eventos ---
    event NuevaOferta(address indexed oferente, uint256 monto, uint256 timestamp);
    event SubastaFinalizada(address ganador, uint256 monto);
    event Reembolso(address indexed oferente, uint256 monto);

    // --- Modificadores ---
    modifier soloMientrasActiva() {
        require(block.timestamp < tiempoFin && !finalizada, "La subasta no esta activa");
        _;
    }

    modifier soloCuandoFinalizada() {
        require(block.timestamp >= tiempoFin || finalizada, "La subasta no ha finalizado");
        _;
    }

    modifier soloNoGanador() {
        require(msg.sender != ganador, "El ganador no puede retirar deposito");
        _;
    }

    // --- Constructor ---
    /// @param _beneficiario Dirección que recibirá los fondos netos
    /// @param _nombre Nombre de la subasta
    /// @param _descripcion Descripción del activo a ser subastado
    /// @param _duracion Duración inicial de la subasta en segundos
    constructor(
        address _beneficiario,
        string memory _nombre,
        string memory _descripcion,
        uint256 _duracion
    ) {
        require(_beneficiario != address(0), "Beneficiario invalido");
        beneficiario = payable(_beneficiario);
        item = Item({nombre: _nombre, descripcion: _descripcion});
        tiempoInicial = block.timestamp;
        tiempoFin = block.timestamp + _duracion;
        finalizada = false;
    }

    // --- Función para ofertar ---
    // @notice Permite ofertar, cumpliendo con el incremento mínimo y extensión de tiempo
    function ofertar() external payable soloMientrasActiva {
        require(msg.value > 0, "Debes enviar ETH");
        uint256 nuevaOferta = depositos[msg.sender] + msg.value;

        // La oferta debe superar la actual en al menos 5%
        require(
            nuevaOferta >= ofertaGanadora + ((ofertaGanadora * constanteIncremento) / 10000) || ofertaGanadora == 0,
            "La oferta debe superar la actual en al menos 5%"
        );

        // Registrar oferente si es su primera oferta
        if (historialOfertas[msg.sender].length == 0) {
            oferentes.push(msg.sender);
        }

        // Registrar depósito y oferta
        depositos[msg.sender] = nuevaOferta;
        historialOfertas[msg.sender].push(Oferta({monto: msg.value, timestamp: block.timestamp}));

        // Actualizar ganador y oferta ganadora
        ganador = msg.sender;
        ofertaGanadora = nuevaOferta;

        // Extender si faltan menos de 10 minutos
        if (tiempoFin - block.timestamp <= 10 minutes) {
            tiempoFin = block.timestamp + extensionTiempo;
        }

        emit NuevaOferta(msg.sender, nuevaOferta, block.timestamp);
    }

    // --- Función para mostrar ganador ---
    // @return Dirección del ganador y monto de la oferta ganadora
    function mostrarGanador() external view returns (address, uint256) {
        return (ganador, ofertaGanadora);
    }

    // --- Función para mostrar todas las ofertas ---
    // @return Lista de oferentes y sus depósitos totales
    function mostrarOfertas() external view returns (address[] memory, uint256[] memory) {
        uint256[] memory montos = new uint256[](oferentes.length);
        for (uint256 i = 0; i < oferentes.length; i++) {
            montos[i] = depositos[oferentes[i]];
        }
        return (oferentes, montos);
    }

    // --- Reembolso parcial durante subasta ---
    // @notice Permite retirar el saldo por encima de la última oferta válida
    function reembolsoParcial() external soloMientrasActiva {
        require(historialOfertas[msg.sender].length > 1, "No hay reembolso parcial disponible");
        uint256 reembolsable = 0;

        // Suma todas las ofertas menos la última
        for (uint256 i = 0; i < historialOfertas[msg.sender].length - 1; i++) {
            reembolsable += historialOfertas[msg.sender][i].monto;
        }
        require(reembolsable > 0, "Nada para reembolsar");

        // Actualiza historial y depósitos
        for (uint256 i = 0; i < historialOfertas[msg.sender].length - 1; i++) {
            historialOfertas[msg.sender][i].monto = 0;
        }
        depositos[msg.sender] -= reembolsable;

        (bool exito, ) = payable(msg.sender).call{value: reembolsable}("");
        require(exito, "Fallo el reembolso parcial");
        emit Reembolso(msg.sender, reembolsable);
    }

    // --- Finalizar subasta y distribuir fondos ---
    // @notice Finaliza la subasta, transfiere fondos y devuelve depósitos a no ganadores
    function finalizar() external soloCuandoFinalizada {
        require(!finalizada, "Ya finalizada");
        finalizada = true;

        // Cobro de comisión
        uint256 comision = (ofertaGanadora * constanteComision) / 10000;
        uint256 neto = ofertaGanadora - comision;

        // Transferir fondos al beneficiario
        (bool exito1, ) = beneficiario.call{value: neto}("");
        require(exito1, "Transferencia al beneficiario fallida");

        // Transferir comisión al deployer (o modificar según política)
        (bool exito2, ) = payable(msg.sender).call{value: comision}("");
        require(exito2, "Transferencia de comision fallida");

        // Devolver depósitos a no ganadores
        for (uint256 i = 0; i < oferentes.length; i++) {
            address oferente = oferentes[i];
            if (oferente != ganador && depositos[oferente] > 0) {
                uint256 monto = depositos[oferente];
                depositos[oferente] = 0;
                (bool exito, ) = payable(oferente).call{value: monto}("");
                require(exito, "Reembolso a oferente fallido");
                emit Reembolso(oferente, monto);
            }
        }

        emit SubastaFinalizada(ganador, ofertaGanadora);
    }
}
