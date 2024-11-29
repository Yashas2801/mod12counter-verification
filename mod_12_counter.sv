module mod_12(clk, rst, datain, dataout, load, mode);
  input [3:0] datain;
  input clk, rst, load, mode;
  output reg [3:0] dataout;

  always @(posedge clk)
  begin
    if (rst)
      dataout <= 4'b0000;
    else
    begin
      if (load)
        dataout <= datain;
      else
      begin
        if (mode)
        begin
          if (dataout == 4'b1011)
            dataout <= 4'b0000;
          else
            dataout <= dataout + 1;
        end
        else
        begin
          if (dataout == 4'b0000)
            dataout <= 4'b1011;
          else
            dataout <= dataout - 1;
        end
      end
    end
  end
endmodule

interface counter_if(input bit clk);
	logic [3:0]data_in;
	logic mode;
	logic load;
	logic rst;
	logic [3:0]data_out;	

	clocking wr_drv@(posedge clk);
	default input #1 output #1;
		output data_in;
		output mode;
		output load;
		output rst;
	endclocking

	clocking wr_mon@(posedge clk);
	default input #1 output #1;
		input data_in;
		input mode;
		input load;
		input rst;
	endclocking


	clocking rd_mon@(posedge clk);
	default input #1 output #1;
		input data_out;
	endclocking

	modport WR_DRV_MP(clocking wr_drv);
	modport WR_MON_MP(clocking wr_mon);
	modport RD_MON_MP(clocking rd_mon);

endinterface

class counter_xtn;
	rand bit [3:0]data_in;
	rand bit mode;
	rand bit load;
	rand bit rst;
	bit [3:0]data_out;

	static int no_of_rst;
	static int no_of_load;
	static int no_of_up_count;
	static int no_of_down_count;
	
	constraint c1{data_in inside{[0:11]};}
	constraint c2{mode dist{1:=50,0:=50};}
	constraint c3{load dist{1:=30,0:=70};}
	constraint c4{rst dist{1:=40,0:=80};}
	
	function void display(string message = "default message");
		$display("message = %s",message);
		$display("d_in = %d",data_in);
		$display("d_out = %d",data_out);
		$display("mode = %b",mode);
		$display("load = %b",load);
		$display("rst = %b",rst);
	
	endfunction	

	function void post_randomize();
		if(this.rst==1||this.rst==0)
		 no_of_rst++;
		if(this.load==1 || this.load==0)
	 	no_of_load++;
		if(this.mode==1)
	 	no_of_up_count++;
		if(this.mode==0)
 		no_of_down_count++;
		this.display("randomized data");
	endfunction
	int no_of_trans = 2000;
endclass


class counter_gen;
  counter_xtn xtn;
  counter_xtn data2send;
  mailbox #(counter_xtn) gen2dr;

  function new(mailbox #(counter_xtn) gen2dr);
    this.gen2dr = gen2dr;
    this.xtn = new();
  endfunction

  virtual task start();
    fork
      begin
        for (int i = 0; i < xtn.no_of_trans; i++) begin
          assert(xtn.randomize());
          data2send = new xtn;
          gen2dr.put(data2send);
        end
      end
    join_none
  endtask
endclass


class write_driver;
    virtual counter_if.WR_DRV_MP wr_drv_if;
    counter_xtn data2duv;
    mailbox #(counter_xtn)gen2wd;
    
    function new(virtual counter_if.WR_DRV_MP wr_drv_if,
		 mailbox #(counter_xtn) gen2wd);
        this.wr_drv_if = wr_drv_if;
        this.gen2wd = gen2wd;
    endfunction
    
    virtual task drive();
        begin
            @(wr_drv_if.wr_drv);
            wr_drv_if.wr_drv.load <= data2duv.load;
            wr_drv_if.wr_drv.data_in <= data2duv.data_in;
            wr_drv_if.wr_drv.mode <= data2duv.mode;
		wr_drv_if.wr_drv.rst <= data2duv.rst;
        end
    endtask
    
    virtual task start();
        fork
            forever
            begin
                gen2wd.get(data2duv);
                drive();
            end
        join_none;
    endtask
endclass



class write_monitor;
    virtual counter_if.WR_MON_MP wr_mon_if;
    counter_xtn wr_data;
    counter_xtn data2rm;
    mailbox #(counter_xtn)mon2rm;

    function new(virtual counter_if.WR_MON_MP wr_mon_if,
			 mailbox #(counter_xtn)mon2rm);
        this.wr_mon_if = wr_mon_if;
        this.mon2rm = mon2rm;
        this.wr_data = new();
    endfunction

    virtual task monitor();
        begin
            @(wr_mon_if.wr_mon)
            begin
                wr_data.mode = wr_mon_if.wr_mon.mode;
                wr_data.load = wr_mon_if.wr_mon.load;
                wr_data.data_in = wr_mon_if.wr_mon.data_in;
		wr_data.rst = wr_mon_if.wr_mon.rst;
                wr_data.display("from write monitor");
            end
        end
    endtask

    virtual task start();
        fork forever
            begin
                monitor();
                data2rm = new wr_data;
                mon2rm.put(data2rm);
            end
        join_none
    endtask
endclass

class read_monitor;
	virtual counter_if.RD_MON_MP rd_mon_if;
	counter_xtn rd_data;
	counter_xtn data2sb;
	mailbox #(counter_xtn)mon2sb;
	
	function new(virtual counter_if.RD_MON_MP rd_mon_if,
			mailbox #(counter_xtn)mon2sb);
	
		this.rd_mon_if = rd_mon_if;
		this.mon2sb = mon2sb;
		rd_data = new;
	endfunction

	virtual task monitor;
	begin 
		@(rd_mon_if.rd_mon)
		begin
			rd_data.data_out = rd_mon_if.rd_mon.data_out;
			rd_data.display("from read monitor");	
		end
	end
	endtask
	
	virtual task start;
	fork
		forever begin
			monitor;
			data2sb = new rd_data;
			mon2sb.put(data2sb);
		end

	join_none
	endtask
		
endclass

class count_model;
	counter_xtn w_data;
	logic [3:0]counter;
	
	mailbox #(counter_xtn)wrmon2rm;
	mailbox #(counter_xtn)rm2sb;
	
	function new(mailbox #(counter_xtn)wrmon2rm,
			mailbox #(counter_xtn)rm2sb);
		this.wrmon2rm = wrmon2rm;
		this.rm2sb = rm2sb;
	endfunction

	virtual task count_mod(counter_xtn model_counter);
		if(model_counter.rst)
			counter <= 0;
		else begin
			if(model_counter.load)
				counter <= model_counter.data_in;
			else begin
				if(model_counter.mode ==1)begin
					if(counter == 11)
						counter<= 0;

					else
						counter <= counter +1;
				end
				if(model_counter.mode == 0)begin
					if(counter == 0)
						counter <= 11;
					else 
						counter <= counter-1;
				end
				
			end
		end
	endtask

	virtual task start;
	fork
		forever begin
			wrmon2rm.get(w_data);
			count_mod(w_data);
			w_data.data_out = counter;
			rm2sb.put(w_data);
		end

	join_none	
	endtask
endclass



class count_sb;
	event DONE;

	counter_xtn rm_data;
	counter_xtn rd_data;
	counter_xtn cov_data;	

	mailbox #(counter_xtn)rm2sb;
	mailbox #(counter_xtn)rd2sb;

	static int ref_data = 0;
	static int rd_mon_data = 0;
	static int data_verified = 0;	
	static int data_match = 0;
	static int data_mismatch = 0;

	covergroup counter_coverage;
		reset : coverpoint cov_data.rst;
		Load : coverpoint cov_data.load;
		Mode : coverpoint cov_data.mode;
		IN : coverpoint cov_data.data_in { bins datain[] = {[0:11]};}
		OUT : coverpoint cov_data.data_out { bins dataout[] = {[0:11]};}
		ldxdin : cross Load,IN;
		moxldxxin: cross Mode,Load,IN;
	endgroup
	
	function new(mailbox #(counter_xtn)rm2sb,
        	mailbox #(counter_xtn)rd2sb);
		this.rm2sb = rm2sb;
		this.rd2sb = rd2sb;
		counter_coverage = new;
	endfunction

	virtual task start;
	fork
		forever begin
			rm2sb.get(rm_data);
			ref_data ++;
			rd2sb.get(rd_data);
			rd_mon_data ++;
			check(rd_data);
		end
	join_none
	endtask

	virtual task check(counter_xtn rddata);
	begin
		if(rddata.data_out == rm_data.data_out)begin
			$display("data_out matched");
			data_match++;
		end
		else begin 
			$display("data_mismatch");
			data_mismatch++;
		end
	end
		cov_data = new rm_data;
		counter_coverage.sample;
		data_verified ++;
		if(data_verified >= rm_data.no_of_trans)
			-> DONE;
	endtask	 	

	virtual task report;
		$display("/////////////////////////////////////");
		$display("MATCHED DATA = %d",data_match);
		$display("VERIFIED DATA = %d",data_verified);
		$display("MISMATCHED DATA = %d", data_mismatch);
		$display("/////////////////////////////////////");

	endtask
endclass

class counter_env;
	virtual counter_if.WR_DRV_MP wr_drv_if;
	virtual counter_if.WR_MON_MP wr_mon_if;
	virtual counter_if.RD_MON_MP rd_mon_if;
	
	mailbox #(counter_xtn)gen2wr= new;
	mailbox #(counter_xtn)wr2rm= new;
	mailbox #(counter_xtn)rd2sb= new;
	mailbox #(counter_xtn)rm2sb= new;

	counter_gen gen;
	write_driver wr_dr;
	write_monitor wr_mo;
	read_monitor rd_mo;
	count_model c_mo;
	count_sb c_sb;

	function new(virtual counter_if.WR_DRV_MP wr_drv_if,
        virtual counter_if.WR_MON_MP wr_mon_if,
        virtual counter_if.RD_MON_MP rd_mon_if);
		this.wr_drv_if = wr_drv_if;
		this.wr_mon_if = wr_mon_if;
		this.rd_mon_if = rd_mon_if;
	
	endfunction

	virtual task build;
		gen = new(gen2wr);
		wr_dr = new(wr_drv_if,gen2wr);
		wr_mo = new(wr_mon_if,wr2rm);
		rd_mo = new(rd_mon_if,rd2sb);
		c_mo = new(wr2rm,rm2sb);
		c_sb = new(rm2sb,rd2sb);
	endtask

	virtual task run;
		start;
		stop;
		c_sb.report;
	endtask

	virtual task start;
		gen.start;
		wr_dr.start;
		wr_mo.start;
		rd_mo.start;
		c_mo.start;
		c_sb.start;
	endtask

	virtual task stop;
		wait(c_sb.DONE.triggered);
	endtask
endclass


class test;
	virtual counter_if.WR_DRV_MP wr_drv_if;
	virtual counter_if.RD_MON_MP rd_mon_if;
	virtual counter_if.WR_MON_MP wr_mon_if;

	counter_env envh;
	function new(virtual counter_if.WR_DRV_MP wr_drv_if,
			virtual counter_if.WR_MON_MP wr_mon_if,
			virtual counter_if.RD_MON_MP rd_mon_if);

		this.wr_drv_if = wr_drv_if;
		this.wr_mon_if = wr_mon_if;
		this.rd_mon_if = rd_mon_if;
	envh = new(wr_drv_if,wr_mon_if,rd_mon_if);	

	endfunction

	virtual task build;
		envh.build;	
	endtask

	virtual task run;
		envh.run;
	endtask

	
endclass


module top;
	bit clk;
	counter_if duv_if(clk);	
	parameter cycle = 10;
	
	test tc0;
	
	mod_12 DUV(.clk(clk),.rst(duv_if.rst),.datain(duv_if.data_in),.dataout(duv_if.data_out),
			.load(duv_if.load),.mode(duv_if.mode));
	initial begin
		forever #(cycle) clk =~clk; 
	end

	initial begin
		if($test$plusargs("TEST1"))begin
			tc0 = new(duv_if,duv_if,duv_if);
			//no_of_trans = 2000;
			tc0.build;	
			tc0.run;
			$finish;
		end
	end
	
		
endmodule







