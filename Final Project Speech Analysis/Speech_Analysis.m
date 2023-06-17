%% 1.Get the data ready for analysis
close all ; clear ; clc
% get a record from user
recobj=audiorecorder;
recDuration= 3;
disp('start recording..')
recordblocking(recobj,recDuration);
disp('stop recording')
% play the record
play(recobj);
% get the data form the record
data = getaudiodata(recobj);
%plot the data
plot(data)
title('original speech')
% Define the frame size
frame_time=20e-3;
frame_size=(frame_time/recDuration)*length(data);
T_frame=zeros(frame_size,1);
n_frames=length(data)/frame_size;


%% 2.Generate codebooks

cb_size=1024;

cb_noise=zeros(length(T_frame),cb_size);
for i=1:cb_size
    noise=randn(10000,1);
    noise = sqrt(var(tt)) * (noise - mean(noise)) / std(noise) + mean(tt);
    %   noise= 2 * (noise - min(noise)) / (max(noise) - min(noise)) - 1;
    
    cb_noise(:,i)=noise(length(noise)/2:length(noise)/2+frame_size-1);
    
    
end

%% 3.Start Analysis (TX)

%loop to simulate the data come in stream (realtime)
PWR=zeros(1,n_frames);
lpc_taps=12;
L_initial=zeros(lpc_taps,1);
S_initial=zeros(lpc_taps,1);
L_lar = zeros(lpc_taps,1);
S_lar = zeros(lpc_taps,1);
Lx_initial=zeros(lpc_taps,1);
Sx_initial=zeros(lpc_taps,1);

RX_data = zeros(length(data),1);
RX_data = 0;

for i=1:n_frames
    
    % get a frame from the data
    T_frame=data( ((i-1)*frame_size)+1 :i*frame_size);
    frame= T_frame;
    AC = xcorr(T_frame);
    
    AC= AC(160:end);
    PWR(i)=sum(T_frame.^2)/frame_size;
    [~, idx] = sort(AC,'descend');
    
    for j=1:length(idx)-1
        if(idx(j+1)>idx(j)+1)
            pitch = idx(j+1);
            break;
        end
    end
    
    
    % check pitch period is within average range for being voiced
    pitch_T = ((pitch/frame_size)*frame_time)*1e3;
    if(pitch_T>2.5)
        disp("voiced");
        Received = "voiced";
        
        %Long-term LPC parameters for voiced & unvoiced
        frame_x = [T_frame(1); T_frame(pitch-5:end)];
        L_lpc = lpc(frame_x,lpc_taps);
        [T_frame ,L_final ]=filter(L_lpc,1,T_frame,L_initial);
        L_initial=L_final;
        
        frame_ac=xcorr(T_frame);
        
    end
    
    %short term lpc for both voiced and unvoiced frame
    S_lpc = lpc(T_frame,lpc_taps);
    [T_frame , S_final ]=filter(S_lpc,1,T_frame,S_initial);
    S_initial=S_final;
    frame_ac=xcorr(T_frame);
    if(i==100)
        tt=T_frame;
        plot(tt);
    end
    
    %T_frame= (T_frame-mean(T_frame))/(std(T_frame));
    %T_frame = 2 * (T_frame - min(T_frame)) / (max(T_frame) - min(T_frame)) - 1;
    
    
    %        % Get log area ratio of coff LPC
    %         L_lar = rc2lar(L_lpc);
    %         S_lar = rc2lar(S_lpc);
    
    %find the minimum euclidean distance in code book noise
    euc_dis=zeros(cb_size,1);
    for ii=1:cb_size
        
        euc_dis(ii)=sum((cb_noise(:,ii)-T_frame).^2);
    end
    
    [~,idx1]=sort(euc_dis);
    noise_idx=idx1(1);
    
    
    
    %% 4.Synthesis
    
    %Selected CodeBook
    RX_noise = cb_noise(:,noise_idx);
    RX_noise = sqrt(var(T_frame)) * (RX_noise - mean(RX_noise)) / std(RX_noise) + mean(T_frame);
    
    %inverse short lpc
    [RX_frame,Sx_final] = filter(1,S_lpc,RX_noise,Sx_initial);
    Sx_initial = Sx_final;
    
    if(Received == "voiced")
        [RX_frame,Lx_final] = filter(1,L_lpc,RX_noise,Lx_initial);
        Lx_initial = Lx_final;
    end
    
    RX_data=[RX_data; RX_frame];
    
    
end
sound(RX_data)








