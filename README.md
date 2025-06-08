---
# Contrato de Subasta (Auction.sol)

Este contrato inteligente implementa una subasta básica donde los participantes pueden pujar por un artículo. La oferta más alta al finalizar el tiempo gana el artículo. Incluye funcionalidades para gestionar ofertas, reembolsos de depósitos y el retiro de fondos por parte del propietario.

---
## Características

* **Propietario del Contrato**: Solo el `owner` puede finalizar la subasta y retirar los fondos.
* **Duración de la Subasta**: Se establece al momento del despliegue del contrato.
* **Pujas Dinámicas**: Las ofertas deben ser al menos un **5% más altas** que la oferta actual más alta.
* **Extensión del Tiempo**: Si una puja se realiza en los últimos 10 minutos de la subasta, el tiempo de finalización se extiende por 10 minutos adicionales.
* **Gestión de Depósitos**: Los postores pueden depositar más Ether del necesario para su puja actual y retirar el exceso si lo desean antes de que finalice la subasta.
* **Finalización de Subasta**: La subasta termina automáticamente al expirar el tiempo, pero el `owner` debe llamar a la función `endAuction` para registrar oficialmente el fin y permitir los reembolsos.
* **Reembolsos**: Los postores no ganadores pueden solicitar el reembolso de su depósito, con una **comisión del 2%** retenida por el contrato.
* **Retiro de Fondos**: El `owner` puede retirar todos los fondos del contrato una vez finalizada la subasta y determinado un ganador.

---
## Eventos

* `NewOffer(address indexed bidder, uint amount)`: Emitido cada vez que se realiza una nueva oferta.
* `AuctionEnded(address indexed winner, uint winningBid)`: Emitido cuando el propietario finaliza la subasta, indicando el ganador y la puja final.
* `DepositRefunded(address indexed bidder, uint amount)`: Emitido cuando un postor no ganador recibe un reembolso de su depósito.
* `PartialRefund(address indexed bidder, uint amount)`: Emitido cuando un postor retira un exceso de depósito.

---
## Modificadores

* `onlyOwner()`: Restringe el acceso a funciones solo para el propietario del contrato.
* `auctionNotEnded()`: Asegura que una función solo pueda ser llamada mientras la subasta está activa.
* `auctionEndedModifier()`: Asegura que una función solo pueda ser llamada cuando la subasta ha terminado y no ha sido finalizada previamente.

---
## Funciones (Interfaz Pública)

### Constructor

* `constructor(uint _auctionDurationInMinutes, string memory _itemDescription)`
    * Se ejecuta una sola vez al desplegar el contrato.
    * Inicializa el propietario con la dirección que despliega el contrato (`msg.sender`).
    * Establece el tiempo de finalización de la subasta basado en `_auctionDurationInMinutes`.
    * Asigna una descripción al artículo subastado.
    * `_auctionDurationInMinutes`: Duración de la subasta en minutos.
    * `_itemDescription`: Descripción del artículo a subastar.

### Funciones de Pujas

* `bid() public payable auctionNotEnded`
    * Permite a cualquier dirección hacer una oferta.
    * Debe enviar Ether (`payable`).
    * La oferta debe ser al menos un 5% mayor que la `highestBid` actual. Si `highestBid` es 0, la oferta mínima es 1 Wei.
    * Extiende el tiempo de la subasta si la oferta se realiza en los últimos 10 minutos.
    * Almacena el valor total depositado y la puja actual del postor.
    * Actualiza `highestBid` y `highestBidder` si la oferta es la más alta.

* `withdrawExcessDeposit() public auctionNotEnded`
    * Permite a un postor retirar la parte de su depósito que excede su puja actual más alta.
    * Útil si un postor depositó mucho pero luego fue superado por una cantidad menor.

### Funciones de Finalización y Resultados

* `endAuction() public onlyOwner auctionEndedModifier`
    * Solo puede ser llamada por el `owner` una vez que la subasta ha terminado por tiempo.
    * Registra que la subasta ha terminado (`auctionEnded = true`).
    * Emite el evento `AuctionEnded` con el ganador y la puja final.
    * Requiere que se hayan realizado ofertas.

* `showWinner() public view returns (address, uint)`
    * Devuelve la dirección del postor ganador y la cantidad de la puja ganadora.
    * Solo se puede llamar después de que la subasta haya finalizado (`auctionEnded = true`).

* `getBidOf(address _bidder) public view returns (uint)`
    * Permite consultar la puja más alta de una dirección específica.

### Funciones de Gestión de Fondos

* `refundDeposit() public`
    * Permite a los postores que no ganaron la subasta solicitar el reembolso de su depósito.
    * Se aplica una **comisión del 2%** sobre el monto reembolsado.
    * Solo se puede llamar después de que la subasta haya finalizado.
    * El ganador no puede solicitar un reembolso.

* `withdrawFunds() public onlyOwner`
    * Permite al `owner` retirar todos los fondos acumulados en el contrato.
    * Solo puede ser llamada por el `owner` y después de que la subasta haya terminado.

---
## Despliegue y Uso

Para desplegar y usar este contrato, necesitarás una herramienta compatible con Ethereum como Remix o Hardhat.

1.  **Compilar**: Compila el contrato `Auction.sol` con una versión de Solidity compatible (por ejemplo, `0.8.20`).
2.  **Desplegar**: Despliega el contrato, proporcionando la duración de la subasta en minutos y una descripción del artículo.
3.  **Participar**:
    * Los usuarios pueden llamar a `bid()` enviando Ether para hacer sus ofertas.
    * Los postores pueden usar `withdrawExcessDeposit()` para recuperar Ether no utilizado en su puja actual.
    * Una vez que el tiempo de la subasta ha expirado, el `owner` debe llamar a `endAuction()`.
    * Los postores no ganadores pueden llamar a `refundDeposit()` para obtener su reembolso.
    * El `owner` puede llamar a `withdrawFunds()` para recolectar el Ether de la puja ganadora y las comisiones.

---
## Consideraciones de Seguridad

* **Reentrancy**: El contrato utiliza el patrón `checks-effects-interactions` y `call{value:}` para mitigar ataques de reentrancy en las funciones de retiro.
* **Overflow/Underflow**: Solidity 0.8.0 y superior incorpora `SafeMath` por defecto, lo que protege contra desbordamientos y subdesbordamientos aritméticos.
* **Gas Limits**: Ten en cuenta los límites de gas de la red al realizar transacciones.
* **Comisión de Reembolso**: Una comisión del 2% se aplica a los reembolsos de los postores no ganadores.

---
