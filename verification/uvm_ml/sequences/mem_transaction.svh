`ifndef MEM_TRANSACTION_SVH
`define MEM_TRANSACTION_SVH

typedef enum bit [1:0] {
  MEM_READ     = 2'h0,
  MEM_WRITE    = 2'h1,
  MEM_TLB_LOAD = 2'h3
} mem_op_type_e;

typedef enum bit [3:0] {
  MEM_STATUS_OK        = 4'h0,
  MEM_STATUS_ERR_ADDR  = 4'h1,
  MEM_STATUS_ERR_ACC   = 4'h2,
  MEM_STATUS_ERR_WRITE = 4'h3,
  MEM_STATUS_PENDING   = 4'hF
} mem_status_e;

class mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(mem_transaction)
  
  rand mem_op_type_e op_type;
  rand bit [63:0]    virt_addr;
  rand bit [7:0]     byte_mask;
  rand bit [63:0]    data;
  rand bit [63:0]    tlb_virt_base;
  rand bit [63:0]    tlb_phys_base;
  
  mem_status_e       status;
  bit [63:0]         phys_addr;
  bit                response_ready;
  time               timestamp;
  
  constraint valid_op_type_c {
    op_type inside {MEM_READ, MEM_WRITE, MEM_TLB_LOAD};
  }
  
  constraint valid_byte_mask_c {
    byte_mask != 0;
  }
  
  constraint reasonable_addresses_c {
    virt_addr[63:48] == 0;
    tlb_virt_base[63:48] == 0;
    tlb_phys_base[63:48] == 0;
  }
  
  constraint tlb_load_fields_c {
    if (op_type == MEM_TLB_LOAD) {
      tlb_virt_base[11:0] == 0;
      tlb_phys_base[11:0] == 0;
    }
  }

  function new(string name = "mem_transaction");
    super.new(name);
    status = MEM_STATUS_PENDING;
    response_ready = 0;
    timestamp = 0;
  endfunction

  function void do_copy(uvm_object rhs);
    mem_transaction rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("MEM_TXN", "Failed to cast object")
    end
    super.do_copy(rhs);
    op_type = rhs_.op_type;
    virt_addr = rhs_.virt_addr;
    byte_mask = rhs_.byte_mask;
    data = rhs_.data;
    tlb_virt_base = rhs_.tlb_virt_base;
    tlb_phys_base = rhs_.tlb_phys_base;
    status = rhs_.status;
    phys_addr = rhs_.phys_addr;
    response_ready = rhs_.response_ready;
    timestamp = rhs_.timestamp;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    mem_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            (op_type == rhs_.op_type) &&
            (virt_addr == rhs_.virt_addr) &&
            (byte_mask == rhs_.byte_mask) &&
            (data == rhs_.data) &&
            (status == rhs_.status));
  endfunction

  function string convert2string();
    string s;
    s = $sformatf("MemTransaction: op=%s addr=0x%0h mask=0x%0h data=0x%0h status=%s",
                  op_type.name(), virt_addr, byte_mask, data, status.name());
    if (op_type == MEM_TLB_LOAD) begin
      s = {s, $sformatf(" tlb_virt=0x%0h tlb_phys=0x%0h", tlb_virt_base, tlb_phys_base)};
    end
    return s;
  endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_string("op_type", op_type.name());
    printer.print_field("virt_addr", virt_addr, 64, UVM_HEX);
    printer.print_field("byte_mask", byte_mask, 8, UVM_HEX);
    printer.print_field("data", data, 64, UVM_HEX);
    printer.print_string("status", status.name());
    if (op_type == MEM_TLB_LOAD) begin
      printer.print_field("tlb_virt_base", tlb_virt_base, 64, UVM_HEX);
      printer.print_field("tlb_phys_base", tlb_phys_base, 64, UVM_HEX);
    end
  endfunction

endclass

`endif
