import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import random

@cocotb.test()
async def test_axil_adapter_basic(dut):
    """Basic test for AXI-Lite adapter - 32-bit transactions only"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz
    cocotb.start_soon(clock.start())
    
    # Initialize all signals to 0
    dut.rstn.value = 0
    
    # Master interface (slave to the adapter)
    dut.m_axil_awready.value = 0
    dut.m_axil_wready.value = 0  
    dut.m_axil_bresp.value = 0
    dut.m_axil_bvalid.value = 0
    dut.m_axil_arready.value = 0
    dut.m_axil_rdata.value = 0
    dut.m_axil_rresp.value = 0
    dut.m_axil_rvalid.value = 0
    
    # Slave interface (master to the adapter)
    dut.s_axil_awaddr.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wdata.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 0
    dut.s_axil_araddr.value = 0
    dut.s_axil_arvalid.value = 0
    dut.s_axil_rready.value = 0
    
    # Reset sequence
    await ClockCycles(dut.clk, 5)
    dut.rstn.value = 1
    await ClockCycles(dut.clk, 5)
    
    dut._log.info("Starting AXI-Lite Adapter Test - 32-bit only")
    
    # Test Write Transaction
    test_addr = 0x1000
    test_data = 0x12345678
    
    dut._log.info(f"Testing write: addr=0x{test_addr:08x}, data=0x{test_data:08x}")
    
    # Start write transaction from slave side
    dut.s_axil_awaddr.value = test_addr
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wdata.value = test_data
    dut.s_axil_wvalid.value = 1
    
    await RisingEdge(dut.clk)
    
    # Wait for adapter to propagate address to master
    timeout = 0
    while dut.m_axil_awvalid.value == 0 and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.m_axil_awvalid.value == 1, "Master awvalid should be asserted"
    assert int(dut.m_axil_awaddr.value) == test_addr, f"Address mismatch: got 0x{int(dut.m_axil_awaddr.value):08x}"
    
    # Master accepts address
    dut.m_axil_awready.value = 1
    await RisingEdge(dut.clk)
    dut.m_axil_awready.value = 0
    
    # Wait for data to propagate
    timeout = 0
    while dut.m_axil_wvalid.value == 0 and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.m_axil_wvalid.value == 1, "Master wvalid should be asserted"
    assert int(dut.m_axil_wdata.value) == test_data, f"Data mismatch: got 0x{int(dut.m_axil_wdata.value):08x}"
    
    # Master accepts data
    dut.m_axil_wready.value = 1
    await RisingEdge(dut.clk)
    dut.m_axil_wready.value = 0
    
    # Master provides write response
    dut.m_axil_bresp.value = 0  # OKAY
    dut.m_axil_bvalid.value = 1
    dut.s_axil_bready.value = 1
    
    await RisingEdge(dut.clk)
    
    # Wait for response to propagate back to slave
    timeout = 0
    while dut.s_axil_bvalid.value == 0 and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.s_axil_bvalid.value == 1, "Slave bvalid should be asserted"
    assert int(dut.s_axil_bresp.value) == 0, "Response should be OKAY"
    
    # Complete write transaction
    await RisingEdge(dut.clk)
    dut.m_axil_bvalid.value = 0
    dut.s_axil_bready.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    
    await ClockCycles(dut.clk, 5)
    
    # Test Read Transaction
    dut._log.info(f"Testing read: addr=0x{test_addr:08x}")
    
    # Start read transaction
    dut.s_axil_araddr.value = test_addr
    dut.s_axil_arvalid.value = 1
    
    await RisingEdge(dut.clk)
    
    # Wait for read address to propagate
    timeout = 0
    while dut.m_axil_arvalid.value == 0 and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.m_axil_arvalid.value == 1, "Master arvalid should be asserted"
    assert int(dut.m_axil_araddr.value) == test_addr, f"Read address mismatch"
    
    # Master accepts read address
    dut.m_axil_arready.value = 1
    await RisingEdge(dut.clk)
    dut.m_axil_arready.value = 0
    
    # Master provides read data
    dut.m_axil_rdata.value = test_data
    dut.m_axil_rresp.value = 0  # OKAY
    dut.m_axil_rvalid.value = 1
    dut.s_axil_rready.value = 1
    
    await RisingEdge(dut.clk)
    
    # Wait for read data to propagate
    timeout = 0
    while dut.s_axil_rvalid.value == 0 and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.s_axil_rvalid.value == 1, "Slave rvalid should be asserted"
    assert int(dut.s_axil_rdata.value) == test_data, f"Read data mismatch: got 0x{int(dut.s_axil_rdata.value):08x}"
    assert int(dut.s_axil_rresp.value) == 0, "Read response should be OKAY"
    
    # Complete read transaction
    await RisingEdge(dut.clk)
    dut.m_axil_rvalid.value = 0
    dut.s_axil_rready.value = 0
    dut.s_axil_arvalid.value = 0
    
    await ClockCycles(dut.clk, 10)
    
    dut._log.info("Basic test PASSED!")

@cocotb.test()
async def test_multiple_transactions(dut):
    """Test multiple 32-bit read/write transactions"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rstn.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Initialize all master interface signals
    dut.m_axil_awready.value = 0
    dut.m_axil_wready.value = 0
    dut.m_axil_bresp.value = 0
    dut.m_axil_bvalid.value = 0
    dut.m_axil_arready.value = 0
    dut.m_axil_rdata.value = 0
    dut.m_axil_rresp.value = 0
    dut.m_axil_rvalid.value = 0
    
    # Initialize all slave interface signals
    dut.s_axil_awaddr.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wdata.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 0
    dut.s_axil_araddr.value = 0
    dut.s_axil_arvalid.value = 0
    dut.s_axil_rready.value = 0
    
    # Simple memory model
    memory = {}
    
    # Test 3 transactions
    for i in range(3):
        addr = 0x1000 + (i * 4)  # Word aligned addresses
        data = 0x10000000 + (i * 0x11111111)  # Unique data pattern
        
        dut._log.info(f"Transaction {i+1}: Write 0x{data:08x} to 0x{addr:08x}")
        
        # === WRITE TRANSACTION ===
        dut.s_axil_awaddr.value = addr
        dut.s_axil_awvalid.value = 1
        dut.s_axil_wdata.value = data
        dut.s_axil_wvalid.value = 1
        
        await RisingEdge(dut.clk)
        
        # Wait for master interface
        while not (dut.m_axil_awvalid.value and dut.m_axil_wvalid.value):
            await RisingEdge(dut.clk)
            
        # Master accepts
        dut.m_axil_awready.value = 1
        dut.m_axil_wready.value = 1
        await RisingEdge(dut.clk)
        dut.m_axil_awready.value = 0
        dut.m_axil_wready.value = 0
        
        # Store in memory model
        memory[addr] = data
        
        # Master responds
        dut.m_axil_bresp.value = 0
        dut.m_axil_bvalid.value = 1
        dut.s_axil_bready.value = 1
        await RisingEdge(dut.clk)
        
        # Wait for response to propagate
        while not dut.s_axil_bvalid.value:
            await RisingEdge(dut.clk)
            
        await RisingEdge(dut.clk)
        dut.m_axil_bvalid.value = 0
        dut.s_axil_bready.value = 0
        dut.s_axil_awvalid.value = 0
        dut.s_axil_wvalid.value = 0
        
        await ClockCycles(dut.clk, 2)
        
        # === READ TRANSACTION ===
        dut._log.info(f"Transaction {i+1}: Read from 0x{addr:08x}")
        
        dut.s_axil_araddr.value = addr
        dut.s_axil_arvalid.value = 1
        
        await RisingEdge(dut.clk)
        
        # Wait for master interface
        while not dut.m_axil_arvalid.value:
            await RisingEdge(dut.clk)
            
        # Master accepts
        dut.m_axil_arready.value = 1
        await RisingEdge(dut.clk)
        dut.m_axil_arready.value = 0
        
        # Master responds with data
        expected_data = memory.get(addr, 0)
        dut.m_axil_rdata.value = expected_data
        dut.m_axil_rresp.value = 0
        dut.m_axil_rvalid.value = 1
        dut.s_axil_rready.value = 1
        
        await RisingEdge(dut.clk)
        
        # Wait for data to propagate
        while not dut.s_axil_rvalid.value:
            await RisingEdge(dut.clk)
            
        # Check data
        received_data = int(dut.s_axil_rdata.value)
        assert received_data == data, f"Transaction {i+1}: Expected 0x{data:08x}, got 0x{received_data:08x}"
        
        await RisingEdge(dut.clk)
        dut.m_axil_rvalid.value = 0
        dut.s_axil_rready.value = 0
        dut.s_axil_arvalid.value = 0
        
        await ClockCycles(dut.clk, 2)
    
    dut._log.info("Multiple transaction test PASSED!")

@cocotb.test()
async def test_back_to_back(dut):
    """Test back-to-back transactions"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rstn.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rstn.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Initialize signals
    dut.m_axil_awready.value = 1  # Master always ready
    dut.m_axil_wready.value = 1
    dut.m_axil_arready.value = 1
    dut.s_axil_bready.value = 1   # Slave always ready
    dut.s_axil_rready.value = 1
    
    dut.m_axil_bresp.value = 0
    dut.m_axil_bvalid.value = 0
    dut.m_axil_rresp.value = 0
    dut.m_axil_rvalid.value = 0
    dut.m_axil_rdata.value = 0
    
    # Back-to-back writes
    for i in range(2):
        addr = 0x2000 + (i * 4)
        data = 0x55AA0000 + i
        
        dut.s_axil_awaddr.value = addr
        dut.s_axil_awvalid.value = 1
        dut.s_axil_wdata.value = data
        dut.s_axil_wvalid.value = 1
        
        await RisingEdge(dut.clk)
        
        # Master immediately responds
        dut.m_axil_bvalid.value = 1
        await RisingEdge(dut.clk)
        dut.m_axil_bvalid.value = 0
        
        dut.s_axil_awvalid.value = 0
        dut.s_axil_wvalid.value = 0
        
        dut._log.info(f"Back-to-back write {i+1}: 0x{data:08x} to 0x{addr:08x}")
    
    await ClockCycles(dut.clk, 5)
    dut._log.info("Back-to-back test PASSED!")
