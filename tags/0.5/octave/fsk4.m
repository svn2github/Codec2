% fsk4.mf
% 4FSK modem attempt from the DMR spec

graphics_toolkit("gnuplot");

fm;

% Frequency response of the DMR raised cosine filter 
% from ETSI TS 102 361-1 V2.2.1 page 111
global fsk4_rcf_resp = @(f) 1.0*(f<=1920) - cos((pi*f)/1920).*1.0.*(f>1920 & f<=2880);

%Maximum positive deviation of amy 4FSK symbol
global fsk4_max_deviation = 1944;

%Deviation of the FSK symbols
global fsk4_symbols = [-1944 -648 648 1944];

function fsk4_states = fsk4_init(fsk4_states,Rs)
    global fsk4_max_deviation;
    global fsk4_symbols;
    global fsk4_rcf_resp;

    Fs = fsk4_states.Fs = 48000;  %Sample rate
    Rs = fsk4_states.Rs = Rs;     %Symbol rate
    M = fsk4_states.M = fsk4_states.Fs/fsk4_states.Rs; %Samples per symbol
    
    % Set up 4FSK raised cosine filter. This probably screws up perf if we were using
    % optimal mod and dmeods but helps performance when using nasty old analog FM mods
    % and demods

    rf = (0:(Fs/2));
    tx_filter = fir2(100 ,rf/(Fs/2),fsk4_rcf_resp(rf));
    fsk4_states.tx_filter = tx_filter;
    %Set up the 4FSK symbols
    fsk4_states.symmap = fsk4_symbols / fsk4_max_deviation;
    
    fm_states.Ts = M;
    fm_states.Fs = Fs;
    fm_states.fc = 0;
    fm_states.fm_max = fsk4_max_deviation*2;
    fm_states.fd = fsk4_max_deviation;
    fm_states.pre_emp = fm_states.de_emp = 0;
    fm_states.output_filter = 1;
    fsk4_states.fm_states = analog_fm_init(fm_states);

endfunction 

function d = idmp(data, M)
    d = zeros(1,length(data)/M);
    for i = 1:length(d)
      d(i) = sum(data(1+(i-1)*M:i*M));
    end
endfunction

function [tx, tx_filt, tx_stream] = fsk4_mod(fsk4_states, tx_bits)
  hbits = tx_bits(1:2:length(tx_bits));
  lbits = tx_bits(2:2:length(tx_bits));
  %Pad odd bit lengths
  if(length(hbits)!=length(lbits))
    lbits = [lbits 0]
  end
  tx_symbols = lbits + hbits*2 + 1;
  M = fsk4_states.M;
  nsym = length(tx_symbols);
  nsam = nsym*M;

  tx_stream = zeros(1,nsam);
  for i=1:nsym
    tx_stream(1+(i-1)*M:i*M) = fsk4_states.symmap(tx_symbols(i));
  end
  tx_filt = filter(fsk4_states.tx_filter, 1, tx_stream);
  %tx_filt = tx_filt / max(tx_filt);
  tx = analog_fm_mod(fsk4_states.fm_states, tx_filt);
  figure(10);
  plot(20*log10(abs(fft(tx))))

endfunction

% Integrate and Dump 4FSK demod

function bits = fsk4_demod_thing(fsk4_states, rx)
  global fsk4_symbols;

  M = fsk4_states.M;
  Fs = fsk4_states.Fs;
  t = (0:length(rx)-1);
  symup = fsk4_symbols;
  
  % Integrator is like an FIR filter with rectangular window coeffs.
  % This has some nasty side lobes so lets limit the overall amount
  % of noise getting in.  tx filter just happens to work, but I imagine
  % other LPF would as well.

  rx = filter(fsk4_states.tx_filter, 1, rx);

  sym1m = exp(j*2*pi*(symup(1)/Fs)*t).*rx;
  sym2m = exp(j*2*pi*(symup(2)/Fs)*t).*rx;
  sym3m = exp(j*2*pi*(symup(3)/Fs)*t).*rx;
  sym4m = exp(j*2*pi*(symup(4)/Fs)*t).*rx;

  % this puppy found by experiment between 1 and M. Will vary with different
  % filter impulse responses, as delay will vary.  f you add M to it coarse
  % timing will adjust by 1.

  fine_timing = M+1;

  sym1m = idmp(sym1m(fine_timing:length(sym1m)),M); sym1m = (real(sym1m).^2+imag(sym1m).^2);
  sym2m = idmp(sym2m(fine_timing:length(sym2m)),M); sym2m = (real(sym2m).^2+imag(sym2m).^2);
  sym3m = idmp(sym3m(fine_timing:length(sym3m)),M); sym3m = (real(sym3m).^2+imag(sym3m).^2);
  sym4m = idmp(sym4m(fine_timing:length(sym4m)),M); sym4m = (real(sym4m).^2+imag(sym4m).^2);

  figure(2);
  nsym = 100;
  subplot(411); plot(sym1m(1:nsym))
  subplot(412); plot(sym2m(1:nsym))
  subplot(413); plot(sym3m(1:nsym))
  subplot(414); plot(sym4m(1:nsym))
  
  [x iv] = max([sym1m; sym2m; sym3m; sym4m;]);
  bits = zeros(1,length(iv*2));
  figure(3);
  hist(iv);
  for i=1:length(iv)
    bits(1+(i-1)*2:i*2) = [[1 1];[1 0];[0 1];[0 0]](iv(i),(1:2));
  end
endfunction

function bits = fsk4_demod_two(fsk4_states,rx)
  global fsk4_symbols;
  figure(4);

  Fs = fsk4_states.Fs;
  rf = (0:(Fs/2));
  rx_filter = fir2(100 ,rf/(Fs/2),fsk4_rcf_resp(rf-1000));

  plot(20*log10(abs(fft(rx))));
  Fs = fsk4_states.Fs;
  t = (1:length(rx));
  fsk4_symbols
  rx = filter(rx_filter, 1, rx);
  sym1dc = exp(j*2*pi*(fsk4_symbols(1)/Fs)*t) .* rx;
  sym2dc = exp(j*2*pi*(fsk4_symbols(2)/Fs)*t) .* rx;
  sym3dc = exp(j*2*pi*(fsk4_symbols(3)/Fs)*t) .* rx;
  sym4dc = exp(j*2*pi*(fsk4_symbols(4)/Fs)*t) .* rx;
 
  figure(1);
  %plot(t(1:20:length(t)),abs(idmp(sym1dc,20)),t(1:20:length(t)),abs(idmp(sym2dc,20)));
  
  %figure(2);
  %plot(t(1:20:length(t)),abs(idmp(sym3dc,20)),t(1:20:length(t)),abs(idmp(sym4dc,20)));
  nsym = floor(length(rx)/fsk4_states.M)
  bits = zeros(1,nsym*2);
  syms = zeros(1,nsym);
 
  int1 = abs(idmp(sym1dc,10));  
  int2 = abs(idmp(sym2dc,10));
  int3 = abs(idmp(sym3dc,10));
  int4 = abs(idmp(sym4dc,10));

  plot((1:length(int1)),int1,(1:length(int1)),int2,(1:length(int1)),int3,(1:length(int1)),int4);
 
  for i=(1:nsym)
      st = (i-1)*fsk4_states.M+1;
      en = st+fsk4_states.M-1;
      sym1i = sum(sym1dc(st:en));
      %sym1i = ;
      sym2i = sum(sym2dc(st:en));
      %sym2i = real(sym2i)^2 + imag(sym2i)^2;
      sym3i = sum(sym3dc(st:en));
      %sym3i = real(sym3i)^2 + imag(sym3i)^2;
      sym4i = sum(sym4dc(st:en));
      %sym4i = real(sym4i)^2 + imag(sym4i)^2;
      %[v iv] = max(abs([sym4i sym3i sym2i  sym1i]));
      [v iv] = max([int4(i*2) int3(i*2) int2(i*2) int1(i*2)]);
      syms(i) = iv;
      bits(1+(i-1)*2:i*2) = [[1 1];[1 0];[0 1];[0 0]](iv,(1:2));
  end
  figure(3);
  hist(syms);
  
endfunction
 
%My fourth attempt at a 4fsk demodulator. Based on the same paper as the previous.
function bits = fsk4_demod_four(fsk4_states,rx)

endfunction

%incoherent demod loosly based on another paper. Works, more or less.
% Paper is titled "Design and Implementation of a Fully Digital 4FSK Demodulator"
function [bits err] = fsk4_demod_fmrid(fsk4_states, rx)
  rxd = analog_fm_demod(fsk4_states.fm_states,rx);
  
  rx_filt = filter(fsk4_states.tx_filter, 1, rxd); 
  %rx_filt=rxd;
  figure(1)
  eyediagram(rxd,40);
  sym = afsym = idmp(rx_filt,fsk4_states.M);
  figure(4)
  eyediagram(afsym,2);
  % Demod symbol map. I should probably figure a better way to do this.
  % After integrating, the high symbol tends to be about 7.5
  dmsyms = rot90(fsk4_states.symmap * 20);

  oddsyms  = afsym(1:2:length(afsym));
  evensyms = afsym(2:2:length(afsym));
  figure(2)
  hist(evensyms,30);

  [err, sym] = min(abs(afsym-dmsyms));

  bits = zeros(1,length(sym)*2);
  %Translate symbols back into bits
  figure(3)
  hist(sym);
  for i=1:length(sym)
    bits(1+(i-1)*2:i*2) = [[1 1];[1 0];[0 1];[0 0]](sym(i),(1:2));
  end
endfunction

% Bit error rate test
% for a noise-free channel
% now supports noisy channels
function ber = nfbert(aEsNodB)
  rand('state',1); 
  randn('state',1);

  bitcnt = 48000;
  offset = 29;
  test_bits = [zeros(1,100) rand(1,bitcnt)>.5]; %Random bits. Pad with zeros to prime the filters
  fsk4_states.M = 1;
  fsk4_states = fsk4_init(fsk4_states,2400);
  Fs = fsk4_states.Fs;
  Rb = fsk4_states.Rs * 2;  %Multiply symbol rate by 2, since we have 2 bits per symbol
  
  tx = fsk4_mod(fsk4_states,test_bits);
  printf("M: %d\n", fsk4_states.M);

  %add noise here
  %shamelessly copied from gmsk.m
  EsNo = 10^(aEsNodB/10);
  EbNo = EsNo
  variance = Fs/(Rb*EbNo);
  nsam = length(tx);
  noise = sqrt(variance/2)*(randn(1,nsam) + j*randn(1,nsam));
  rx    = tx*exp(j*pi/2) + noise;
  rx = rx(10:length(rx));
  rx_bits = fsk4_demod_fmrid(fsk4_states,rx);
  ber = 1;
  
  %thing to account for offset from input data to output data
  %No preamble detection yet
  ox = 1;
  for offset = (1:100)
    nerr = sum(xor(rx_bits(offset:length(rx_bits)),test_bits(1:length(rx_bits)+1-offset)));
    bern = nerr/(bitcnt-offset);
    if(bern < ber)
      ox = offset;
      best_nerr = nerr;
    end
    ber = min([ber bern]);
  end
  offset = ox;
  printf("coarse timing: %d nerr: %d\n", offset, best_nerr);
  %plot(xor(rx_bits(offset:length(rx_bits)),test_bits(1:length(rx_bits)+1-offset)));
  %plot((1:1000),rx_bits(1:1000),(1:1000),rx_err(1:1000));
endfunction

