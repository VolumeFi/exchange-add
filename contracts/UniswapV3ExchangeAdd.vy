# @version ^0.2.0

struct MintParams:
    token0: address
    token1: address
    fee: uint256
    tickLower: int128
    tickUpper: int128
    amount0Desired: uint256
    amount1Desired: uint256
    amount0Min: uint256
    amount1Min: uint256
    recipient: address
    deadline: uint256

struct ModifyParams:
    token0: address
    token1: address
    fee: uint256
    tickLower: int128
    tickUpper: int128
    recipient: address
    deadline: uint256

interface ERC721:
    def transferFrom(_from: address, _to: address, _tokenId: uint256): payable

interface NonfungiblePositionManager:
    def increaseLiquidity(tokenId: uint256, amount0Desired: uint256, amount1Desired: uint256, amount0Min: uint256, amount1Min: uint256, deadline: uint256) -> (uint256, uint256, uint256): payable
    def burn(tokenId: uint256): payable

interface WrappedEth:
    def deposit(): payable

event NFLPModified:
    oldTokenId: indexed(uint256)
    newTokenId: indexed(uint256)

event Paused:
    paused: bool

event FeeChanged:
    newFee: uint256

event Log:
    data: bytes32

NONFUNGIBLEPOSITIONMANAGER: constant(address) = 0x048A595f1605BdC9732eBb967a1B9d9D9EE7E6Ff # mainnet address?

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
WETH: constant(address) = 0xc778417E063141139Fce010982780140Aa0cD5Ab # 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
DEADLINE: constant(uint256) = MAX_UINT256 # change

APPROVE_MID: constant(Bytes[4]) = method_id("approve(address,uint256)")
TRANSFER_MID: constant(Bytes[4]) = method_id("transfer(address,uint256)")
TRANSFERFROM_MID: constant(Bytes[4]) = method_id("transferFrom(address,address,uint256)")
CAIPIN_MID: constant(Bytes[4]) = method_id("createAndInitializePoolIfNecessary(address,address,uint24,uint160)")
MINT_MID: constant(Bytes[4]) = method_id("mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))")
POSITIONS_MID: constant(Bytes[4]) = method_id("positions(uint256)")
DECREASELIQUIDITY_MID: constant(Bytes[4]) = method_id("decreaseLiquidity(uint256,uint128,uint256,uint256,uint256)")
COLLECT_MID: constant(Bytes[4]) = method_id("collect(uint256,address,uint128,uint128)")

paused: public(bool)
admin: public(address)
feeAddress: public(address)
feeAmount: public(uint256)

@external
def __init__():
    self.paused = False
    self.admin = msg.sender
    self.feeAddress = 0xf29399fB3311082d9F8e62b988cBA44a5a98ebeD
    self.feeAmount = 5 * 10 ** 15

@internal
@pure
def uintSqrt(x: uint256) -> uint256:
    if x > 3:
        z: uint256 = (x + 1) / 2
        y: uint256 = x
        for i in range(256):
            if y == z:
                return y
            y = z
            z = (x / z + z) / 2
        raise "Did not coverage"
    elif x == 0:
        return 0
    else:
        return 1

@internal
def safeApprove(_token: address, _spender: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            APPROVE_MID,
            convert(_spender, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed approve
    if len(_response) > 0:
        assert convert(_response, bool), "Approve failed"  # dev: failed approve

@internal
def safeTransfer(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFER_MID,
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transfer
    if len(_response) > 0:
        assert convert(_response, bool), "Transfer failed"  # dev: failed transfer

@internal
def safeTransferFrom(_token: address, _from: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFERFROM_MID,
            convert(_from, bytes32),
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transferFrom
    if len(_response) > 0:
        assert convert(_response, bool), "TransferFrom failed"  # dev: failed transferFrom

@internal
def addLiquidity(_tokenId: uint256, sender: address, uniV3Params: MintParams):
    self.safeApprove(uniV3Params.token0, NONFUNGIBLEPOSITIONMANAGER, uniV3Params.amount0Desired)
    self.safeApprove(uniV3Params.token1, NONFUNGIBLEPOSITIONMANAGER, uniV3Params.amount1Desired)
    if _tokenId == 0:
        _response32: Bytes[32] = raw_call(
            NONFUNGIBLEPOSITIONMANAGER,
            concat(
                CAIPIN_MID,
                convert(uniV3Params.token0, bytes32),
                convert(uniV3Params.token1, bytes32),
                convert(uniV3Params.fee, bytes32),
                convert(2 ** 96 * self.uintSqrt(uniV3Params.amount0Desired) / self.uintSqrt(uniV3Params.amount1Desired), bytes32)
            ),
            max_outsize=32
        )
        assert convert(convert(_response32, bytes32), address) != ZERO_ADDRESS, "Create Or Init Pool failed"
        log Log(convert(NONFUNGIBLEPOSITIONMANAGER, bytes32))
        _response128: Bytes[128] = raw_call(
            NONFUNGIBLEPOSITIONMANAGER,
            concat(
                MINT_MID,
                convert(uniV3Params.token0, bytes32),
                convert(uniV3Params.token1, bytes32),
                convert(uniV3Params.fee, bytes32),
                convert(uniV3Params.tickLower, bytes32),
                convert(uniV3Params.tickUpper, bytes32),
                convert(uniV3Params.amount0Desired, bytes32),
                convert(uniV3Params.amount1Desired, bytes32),
                convert(uniV3Params.amount0Min, bytes32),
                convert(uniV3Params.amount1Min, bytes32),
                convert(uniV3Params.recipient, bytes32),
                convert(uniV3Params.deadline, bytes32)
            ),
            max_outsize=128
        )
        tokenId: uint256 = convert(slice(_response128, 0, 32), uint256)
        liquidity: uint256 = convert(slice(_response128, 32, 32), uint256)
        amount0: uint256 = convert(slice(_response128, 64, 32), uint256)
        amount1: uint256 = convert(slice(_response128, 96, 32), uint256)
        if amount0 < uniV3Params.amount0Desired:
            self.safeTransfer(uniV3Params.token0, sender, uniV3Params.amount0Desired - amount0)
            self.safeApprove(uniV3Params.token0, NONFUNGIBLEPOSITIONMANAGER, 0)
        if amount1 < uniV3Params.amount1Desired:
            self.safeTransfer(uniV3Params.token1, sender, uniV3Params.amount1Desired - amount1)
            self.safeApprove(uniV3Params.token1, NONFUNGIBLEPOSITIONMANAGER, 0)
    else:
        liquidity: uint256 = 0
        amount0: uint256 = 0
        amount1: uint256 = 0
        (liquidity, amount0, amount1) = NonfungiblePositionManager(NONFUNGIBLEPOSITIONMANAGER).increaseLiquidity(_tokenId, uniV3Params.amount0Desired, uniV3Params.amount1Desired, uniV3Params.amount0Min, uniV3Params.amount1Min, uniV3Params.deadline)
        if amount0 < uniV3Params.amount0Desired:
            self.safeTransfer(uniV3Params.token0, sender, uniV3Params.amount0Desired - amount0)
            self.safeApprove(uniV3Params.token0, NONFUNGIBLEPOSITIONMANAGER, 0)
        if amount1 < uniV3Params.amount1Desired:
            self.safeTransfer(uniV3Params.token1, sender, uniV3Params.amount1Desired - amount1)
            self.safeApprove(uniV3Params.token1, NONFUNGIBLEPOSITIONMANAGER, 0)

@external
@payable
@nonreentrant('lock')
def addLiquidityEthForUniV3(_tokenId: uint256, uniV3Params: MintParams):
    assert not self.paused, "Paused"
    assert convert(uniV3Params.token0, uint256) < convert(uniV3Params.token1, uint256), "Unsorted tokens"
    fee: uint256 = self.feeAmount
    if fee > 0:
        assert msg.value > fee, "Insufficient fee"
        send(self.feeAddress, fee)
    
    msg_value: uint256 = msg.value - fee
    if uniV3Params.token0 == WETH:
        if msg_value > uniV3Params.amount0Desired:
            send(msg.sender, msg_value - uniV3Params.amount0Desired)
        else:
            assert msg_value == uniV3Params.amount0Desired, "Eth not enough"
        WrappedEth(WETH).deposit(value=uniV3Params.amount0Desired)
        self.safeTransferFrom(uniV3Params.token1, msg.sender, self, uniV3Params.amount1Desired)
    else:
        assert uniV3Params.token1 == WETH, "Not Eth Pair"
        if msg_value > uniV3Params.amount1Desired:
            send(msg.sender, msg_value - uniV3Params.amount1Desired)
        else:
            assert msg_value == uniV3Params.amount1Desired, "Eth not enough"
        WrappedEth(WETH).deposit(value=uniV3Params.amount1Desired)
        self.safeTransferFrom(uniV3Params.token0, msg.sender, self, uniV3Params.amount0Desired)
    self.addLiquidity(_tokenId, msg.sender, uniV3Params)

@external
@payable
@nonreentrant('lock')
def addLiquidityForUniV3(_tokenId: uint256, uniV3Params: MintParams):
    assert not self.paused, "Paused"
    assert convert(uniV3Params.token0, uint256) < convert(uniV3Params.token1, uint256), "Unsorted tokens"
    fee: uint256 = self.feeAmount
    if msg.value > fee:
        send(msg.sender, msg.value - fee)
    else:
        assert msg.value == fee, "Insufficient fee"
    if fee > 0:
        send(self.feeAddress, fee)
    
    self.safeTransferFrom(uniV3Params.token0, msg.sender, self, uniV3Params.amount0Desired)
    self.safeTransferFrom(uniV3Params.token1, msg.sender, self, uniV3Params.amount1Desired)

    self.addLiquidity(_tokenId, msg.sender, uniV3Params)

@external
@payable
@nonreentrant('lock')
def modifyPositionForUniV3NFLP(_tokenId: uint256, modifyParams: ModifyParams):
    assert _tokenId != 0, "Wrong Token ID"
    assert convert(modifyParams.token0, uint256) < convert(modifyParams.token1, uint256), "Unsorted tokens"

    fee: uint256 = self.feeAmount
    if msg.value > fee:
        send(msg.sender, msg.value - fee)
    else:
        assert msg.value == fee, "Insufficient fee"
    if fee > 0:
        send(self.feeAddress, fee)

    ERC721(NONFUNGIBLEPOSITIONMANAGER).transferFrom(msg.sender, self, _tokenId)
    
    _response384: Bytes[384] = raw_call(
        NONFUNGIBLEPOSITIONMANAGER,
        concat(
            POSITIONS_MID,
            convert(_tokenId, bytes32)
        ),
        max_outsize=384,
        is_static_call=True
    )
    liquidity: uint256 = convert(slice(_response384, 224, 32), uint256)
    
    _response64: Bytes[64] = raw_call(
        NONFUNGIBLEPOSITIONMANAGER,
        concat(
            DECREASELIQUIDITY_MID,
            convert(_tokenId, bytes32),
            convert(liquidity, bytes32),
            convert(0, bytes32),
            convert(0, bytes32),
            convert(modifyParams.deadline, bytes32)
        ),
        max_outsize=64
    )

    _response64 = raw_call(
        NONFUNGIBLEPOSITIONMANAGER,
        concat(
            COLLECT_MID,
            convert(_tokenId, bytes32),
            convert(self, bytes32),
            convert(2 ** 128 - 1, bytes32),
            convert(2 ** 128 - 1, bytes32)
        ),
        max_outsize=64
    )
    amount0: uint256 = convert(slice(_response64, 0, 32), uint256)
    amount1: uint256 = convert(slice(_response64, 32, 32), uint256)
    
    NonfungiblePositionManager(NONFUNGIBLEPOSITIONMANAGER).burn(_tokenId)

    _response32: Bytes[32] = raw_call(
        NONFUNGIBLEPOSITIONMANAGER,
        concat(
            CAIPIN_MID,
            convert(modifyParams.token0, bytes32),
            convert(modifyParams.token1, bytes32),
            convert(modifyParams.fee, bytes32),
            convert(2 ** 96 * self.uintSqrt(amount0) / self.uintSqrt(amount1), bytes32)
        ),
        max_outsize=32
    )

    assert convert(convert(_response32, bytes32), address) != ZERO_ADDRESS, "Create Or Init Pool failed"

    self.safeApprove(modifyParams.token0, NONFUNGIBLEPOSITIONMANAGER, amount0)
    self.safeApprove(modifyParams.token1, NONFUNGIBLEPOSITIONMANAGER, amount1)

    _response128: Bytes[128] = raw_call(
        NONFUNGIBLEPOSITIONMANAGER,
        concat(
            MINT_MID,
            convert(modifyParams.token0, bytes32),
            convert(modifyParams.token1, bytes32),
            convert(modifyParams.fee, bytes32),
            convert(modifyParams.tickLower, bytes32),
            convert(modifyParams.tickUpper, bytes32),
            convert(amount0, bytes32),
            convert(amount1, bytes32),
            convert(1, bytes32),
            convert(1, bytes32),
            convert(msg.sender, bytes32),
            convert(modifyParams.deadline, bytes32)
        ),
        max_outsize=128
    )
    tokenId: uint256 = convert(slice(_response128, 0, 32), uint256)
    liquiditynew: uint256 = convert(slice(_response128, 32, 32), uint256)
    amount0new: uint256 = convert(slice(_response128, 64, 32), uint256)
    amount1new: uint256 = convert(slice(_response128, 96, 32), uint256)

    if amount0 > amount0new:
        self.safeTransfer(modifyParams.token0, msg.sender, amount0 - amount0new)
        self.safeApprove(modifyParams.token0, NONFUNGIBLEPOSITIONMANAGER, 0)
    if amount1 > amount1new:
        self.safeTransfer(modifyParams.token1, msg.sender, amount1 - amount1new)
        self.safeApprove(modifyParams.token1, NONFUNGIBLEPOSITIONMANAGER, 0)
    log NFLPModified(_tokenId, tokenId)

# Admin functions
@external
def pause(_paused: bool):
    assert msg.sender == self.admin, "Not admin"
    self.paused = _paused
    log Paused(_paused)

@external
def newAdmin(_admin: address):
    assert msg.sender == self.admin, "Not admin"
    self.admin = _admin

@external
def newFeeAmount(_feeAmount: uint256):
    assert msg.sender == self.admin, "Not admin"
    self.feeAmount = _feeAmount
    log FeeChanged(_feeAmount)

@external
def newFeeAddress(_feeAddress: address):
    assert msg.sender == self.admin, "Not admin"
    self.feeAddress = _feeAddress

@external
@nonreentrant('lock')
def batchWithdraw(token: address[8], amount: uint256[8], to: address[8]):
    assert msg.sender == self.admin, "Not admin"
    for i in range(8):
        if token[i] == VETH:
            send(to[i], amount[i])
        elif token[i] != ZERO_ADDRESS:
            self.safeTransfer(token[i], to[i], amount[i])

@external
@nonreentrant('lock')
def withdraw(token: address, amount: uint256, to: address):
    assert msg.sender == self.admin, "Not admin"
    if token == VETH:
        send(to, amount)
    elif token != ZERO_ADDRESS:
        self.safeTransfer(token, to, amount)

@external
@payable
def __default__():
    assert msg.sender == WETH, "can't receive Eth"