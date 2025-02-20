% 3GPP TR 38.900 based three-dimensional Spatial Channel Model(SCM) model
% Version 0.7 made in 2020-05-10

classdef SCM < handle
    
    % 채널모델 환경 변수
    properties
        % Small scale 변수
        fc              % 신호의 중심 주파수 (Center Frequency), default: 800MHz
        lamda           % 신호의 파장
        fs              % 채널의 sampling frequency
        Ts              % 채널의 sampling period
        tx_ant          % 송신단의 안테나 배열 정보 [ row  col  row_dis  col_dis ]
        rx_ant          % 수신단의 안테나 배열 정보 [ row  col  row_dis  col_dis ]
        tx_d            % 송신단의 안테나 위치 행렬
        rx_d            % 수신단의 안테나 위치 행렬
        Ntx             % 송신단의 안테나 수
        Nrx             % 수신단의 안테나 수
        n_path          % 채널의 path(cluster)의 수
        n_mray          % 채널의 path당 ray의 최대 개수
        n_ray           % 채널의 path당 ray의 수
        asd             % ASD 값
        zsd             % ZSD 값
        asa             % ASA 값
        zsa             % ZSA 값
        xpr_mu          % 직교 패턴간 간섭 비율 기댓값 10^(x/10), x-normal dist
        xpr_std         % 직교 패턴간 간섭 비율 표준편차 10^(x/10), x-normal dist
        pdp             % Power Delay Profile (PDP)
        
        % Large scale 변수
        Gt              % 송신단의 안테나 Gain [dB]
        Gr              % 수신단의 안테나 Gain [dB]
        L               % 시스템 loss factor [dB]
        distance_rate   % 거리 1인 채널에 대한 상대적인 거리 비율
        exp_beta        % Path loss exponent
        sdw_std         % Shadowing 기능의 표준편차, default: 0
        los             % LOS(Line of Sight) 환경을 반영할지 결정하는 변수 1: LOS, 0: non-LOS
        K               % LOS와 non-LOS 신호 전력 사이의 비율 [dB]
        No              % AWGN의 PSD, default: -174 [dB/Hz] (-204 [dbm/Hz])
        ZoD_L           % LOS 방향의 ZoD
        AoD_L           % LOS 방향의 AoD
        ZoA_L           % LOS 방향의 ZoA
        AoA_L           % LOS 방향의 AoA
        p_src           % 송신단의 3차원 위치
        p_dst           % 수신단의 3차원 위치
        abr_src         % 송신단의 3차원 안테나 지향 방향 (alpha, beta, gamma)
        abr_dst         % 수신단의 3차원 안테나 지향 방향 (alpha, beta, gamma)
        los_flag        % LOS 환경 check를 위한 내부 변수
        
        % 방사 패턴 함수 및 변수
        tx_theta        % 송신단의 수직 방사패턴
        tx_phi          % 송신단의 수평 방사패턴
        rx_theta        % 수신단의 수직 방사패턴
        rx_phi          % 수신단의 수평 방사패턴
        
        % 기타 함수 및 모델 변수
        cvt_S2R         % 원통좌표를 직교좌표로 변환하는 함수
        R_mat           % GCS와 LCS간 변환을 위한 행렬 계산 함수
        model_var       % 모델 함수 실행을 위한 변수 저장
    end
    
    
    % 채널모델 함수
    methods
        % 생성자 ===========================================================
        function obj = SCM()
            
            % 3차원 위치 및 송수신 지향 방향 초기화
            obj.p_src = [0 0 0];
            obj.p_dst = [1 0 0];
            obj.abr_src = [0 0 0];
            obj.abr_dst = [pi 0 0];
            
            % Small scale 초기값 설정
            obj.fc = 800e6;
            obj.lamda = [];
            obj.fs = 20e6;
            obj.Ts = [];
            obj.tx_ant = [1 1 0.5 0.5];
            obj.rx_ant = [1 1 0.5 0.5];
            obj.Ntx = [];
            obj.Nrx = [];
            obj.n_path = 7;
            obj.n_mray = 15;
            obj.n_ray = [];
            obj.asd = 3;
            obj.zsd = 3;
            obj.asa = 3;
            obj.zsa = 3;
            obj.xpr_mu = 8;
            obj.xpr_std = 3;
            obj.pdp = [];
            
            % Large scale 초기값 설정
            obj.Gt = 0;
            obj.Gr = 0;
            obj.L = 0;
            obj.distance_rate = 1;
            obj.exp_beta = 3;
            obj.sdw_std = 0;
            obj.los = 0;
            obj.los_flag = 1;
            obj.K = 15;
            obj.No = -174;
            obj.ZoD_L = pi/2;
            obj.AoD_L = 0;
            obj.ZoA_L = pi/2;
            obj.AoA_L = 0;
            
            % 방사 패턴 초기값 설정
            % Radiation Power Pattern이 A(theta, phi) 일 때, mono-pole이면 sqrt(A(theta, phi))
            % Cross-pole인 경우 sqrt(A(theta, phi))*cos(angle)과 sqrt(A(theta, phi))*sin(angle)
            obj.tx_theta = @(theta, phi) 1;
            obj.tx_phi = @(theta, phi) 0;
            obj.rx_theta = @(theta, phi) 1;
            obj.rx_phi = @(theta, phi) 0;
            
            % 함수 초기화
            obj.cvt_S2R = @(theta, phi) [sin(theta).*cos(phi); sin(theta).*sin(phi); cos(theta)];
            obj.R_mat = @(alpha, beta, gamma) ...
                [cos(alpha) -sin(alpha) 0; sin(alpha) cos(alpha) 0; 0 0 1] * ...
                [cos(beta) 0 sin(beta); 0 1 0; -sin(beta) 0 cos(beta)] * ...
                [1 0 0; 0 cos(gamma) -sin(gamma); 0 sin(gamma) cos(gamma) ];
        end
        
        
        % 송수신 위치를 초기화 하는 함수
        function [res_ang, los_flag] = position(obj, p_src, p_dst, abr_src, abr_dst)
            
            % 송수신 지향 방향 초기화(구좌표계 기준)
            if nargin < 5
                % 송신기 안테나 지향 방향 초기화
                R = obj.R_mat(0, 0, 0);
                src_tmp = p_dst - p_src;
                src_tmp = src_tmp / norm(src_tmp);
                obj.abr_src = [angle([1 1j 0] * R.' * src_tmp.') -( pi/2 - acos([0 0 1] * R.' * src_tmp.') ) 0];
                
                % 수신기 안테나 지향 방향 초기화
                dst_tmp = p_src - p_dst;
                dst_tmp = dst_tmp / norm(dst_tmp);
                obj.abr_dst = [angle([1 1j 0] * R.' * dst_tmp.') -( pi/2 - acos([0 0 1] * R.' * dst_tmp.') ) 0];
            else
                obj.abr_src = abr_src;
                obj.abr_dst = abr_dst;
            end
            
            % 3차원 위치 변수 초기화(직교좌표계 기준)
            obj.p_src = p_src;
            obj.p_dst = p_dst;
            
            % 송신 LOS 각도 계산
            src_tmp = obj.p_dst - obj.p_src;
            src_tmp = src_tmp / norm(src_tmp);
            R = obj.R_mat(obj.abr_src(1), obj.abr_src(2), obj.abr_src(3));
            obj.ZoD_L = acos([0 0 1] * R.' * src_tmp.');
            obj.AoD_L = angle([1 1j 0] * R.' * src_tmp.');
            
            % 수신 LOS 각도 계산
            dst_tmp = obj.p_src - obj.p_dst;
            dst_tmp = dst_tmp / norm(dst_tmp);
            R = obj.R_mat(obj.abr_dst(1), obj.abr_dst(2), obj.abr_dst(3));
            obj.ZoA_L = acos([0 0 1] * R.' * dst_tmp.');
            obj.AoA_L = angle([1 1j 0] * R.' * dst_tmp.');
            
            % LOS가 가능한 환경인지 점검
            obj.los_flag = 0;
            flag = zeros(1,4);
            if (obj.ZoD_L >= 0) && ( abs(obj.ZoD_L) <= pi ), flag(1) = 1; end
            if abs(obj.AoD_L) <= pi/2, flag(2) = 1; end
            if (obj.ZoA_L >= 0) && ( abs(obj.ZoA_L) <= pi ), flag(3) = 1; end
            if abs(obj.AoA_L) <= pi/2, flag(4) = 1; end
            if sum(flag) == 4, obj.los_flag = 1; end
            
            % 결과 반환
            los_flag = obj.los_flag;
            res_ang = [obj.ZoD_L obj.AoD_L obj.ZoA_L obj.AoA_L];
        end
        
        
        % 직사각 배열 안테나를 기반으로 안테나 위치 행렬을 초기화하는 함수 ====
        function [] = init_d(obj)
            
            % 송신단의 안테나 위치 행렬
            obj.Ntx = obj.tx_ant(1) * obj.tx_ant(2);
            tdy = obj.tx_ant(3) * obj.lamda;    
            tdz = obj.tx_ant(4) * obj.lamda;
            temp1 = repmat(0:obj.tx_ant(1)-1, obj.tx_ant(2), 1);
            temp2 = repmat(0:obj.tx_ant(2)-1, 1, obj.tx_ant(1));
            obj.tx_d = [ zeros(obj.Ntx,1) temp1(:)*tdy (temp2.')*tdz];
            
            % 수신단의 안테나 위치 행렬
            obj.Nrx = obj.rx_ant(1) * obj.rx_ant(2);
            rdy = obj.rx_ant(3) * obj.lamda;
            rdz = obj.rx_ant(4) * obj.lamda;
            temp3 = repmat(0:obj.rx_ant(1)-1, obj.rx_ant(2), 1);
            temp4 = repmat(0:obj.rx_ant(2)-1, 1, obj.rx_ant(1));
            obj.rx_d = [ zeros(obj.Nrx,1) temp3(:)*rdy (temp4.')*rdz];
        end
        
        
        % 송신단과 수신단의 안테나 수를 초기화 하는 함수 =====================
        function [Rx_ant, Tx_ant] = ant(obj, N_rx, N_tx)
            % 입력으로 받은 송수신 단의 안테나 수를 1차원 배열 안테나로 가정
            Rx_ant = [N_rx 1 0.5 0.5];
            Tx_ant = [N_tx 1 0.5 0.5];
            
            % 환경변수에 값을 저장
            obj.rx_ant = Rx_ant;
            obj.tx_ant = Tx_ant;
            obj.Nrx = Rx_ant(1) * Rx_ant(2);
            obj.Ntx = Tx_ant(1) * Tx_ant(2);
        end
        
        
        % Cluster 및 ray에 할당되는 평균전력을 계산하는 함수 =================
        function [] = def_pow(obj)
            
            % obj.pdp 정의 여부 확인
            if isempty(obj.pdp) == 1
                
                % 지수분포를 기반으로 각 cluster 당 평균 전력 할당
                pw = exp( -(1:obj.n_path) / 5 );
                obj.pdp = ( pw / sum(pw) ).';
                
            else
                obj.n_path = length(obj.pdp);
                obj.pdp = ( obj.pdp / sum(obj.pdp) ).';
            end
            
            % obj.n_ray 정의 여부 확인
            if isempty(obj.n_ray) == 1
                obj.n_ray = ones(1,obj.n_path) * obj.n_mray;
            end
        end
        
        
        % Cluster 및 ray의 ZoD, AoD, ZoA, AoA를 계산하는 함수 ==============
        function [res_angle, angle] = gen_angle(obj)
            % c_ang: 송수신 각도, c_ang = [ ZoD(1:n_path); AoD(1:n_path); ZoA(1:n_path); AoA(1:n_path); ]
            % res_ang: 전체 송수신 각도
    
            % 각 cluster의 ZoD, AoD, ZoA, AoA 중심 값 생성
            angle(1,:) = rand(1, obj.n_path)*pi;         % ZoD
            angle(2,:) = -pi/2 + rand(1, obj.n_path)*pi; % AoD
            angle(3,:) = rand(1, obj.n_path)*pi;         % ZoA
            angle(4,:) = -pi/2 + rand(1, obj.n_path)*pi; % AoA
            
            % 각 ray의 ZoD, AoD, ZoA, AoA 생성
            res_angle = cell(1, obj.n_path);
            for i = 1 : obj.n_path
                
                % ray의 수가 1일 경우에는 중심 각도를 그대로 이용
                if obj.n_ray == 1, tmp_angle = angle;
                else
                    tmp_angle = randn(4, obj.n_ray(i));
                    tmp_angle(1,:) = tmp_angle(1,:) * (obj.zsd * pi/180) + angle(1,i);
                    tmp_angle(2,:) = tmp_angle(2,:) * (obj.asd * pi/180) + angle(2,i);
                    tmp_angle(3,:) = tmp_angle(3,:) * (obj.zsa * pi/180) + angle(3,i);
                    tmp_angle(4,:) = tmp_angle(4,:) * (obj.asa * pi/180) + angle(4,i);
                end
                
                res_angle{i} = tmp_angle;
            end
        end
        
        
        % PAS에 따른 ray의 평균전력을 계산하는 함수 =========================
        function pw = pas(obj, res_angle, ray_num)
            % res_angle: 현재 cluster에 속하는 ray의 각도
            % ray_num: 평균전력을 계산해야하는 ray 중 현재 ray의 번호
            
            % 변수 초기화
            [~, lay_len] = size(res_angle);
            
            % default 평균전력 할당
            pw = 1 / sqrt(lay_len);
        end
        
        
        % Ray 당 채널 계수를 계산하는 함수 ===================================
        function [subpath_coeff] = ray_cal(obj, sample_len, ZoD, AoD, ZoA, AoA, xpr, vel)
            
            % 직교 방사패턴 간섭 계산
            trx_coef = [ obj.rx_theta(ZoA, AoA); obj.rx_phi(ZoA, AoA) ].';
            if xpr == 0, trx_coef = trx_coef * ( exp(2j*pi*rand(1)) .* [1 0; 0 -1] );
            else, trx_coef = trx_coef * ( exp(2j*pi*rand(2)) .* [1 1/sqrt(xpr); 1/sqrt(xpr) 1] ); end
            trx_coef = trx_coef * [ obj.tx_theta(ZoD, AoD); obj.tx_phi(ZoD, AoD)];
            
            % 송수신 안테나 반응 벡터 계산
            rx_r = obj.cvt_S2R(ZoA, AoA);
            sub_rx = exp(2j*pi * obj.rx_d * rx_r / obj.lamda);
            tx_r = obj.cvt_S2R(ZoD, AoD);
            sub_tx = exp(2j*pi * obj.tx_d * tx_r / obj.lamda);
            trx_tmp(1,:,:) = trx_coef * sub_rx * sub_tx.';
            
            % 도플러 벡터 계산
            dop_tmp = zeros(sample_len,1,2);
            if vel == 0, dop_tmp(:,1,1) = ones(sample_len,1,1);
            else
                t_sample = 0 : obj.Ts : obj.Ts * (sample_len-1);
                dop_tmp(:,1,1) = exp(2j*pi * vel * rx_r / obj.lamda * t_sample);
            end
            
            % subpath 값 누적
            subpath_coeff = repmat(trx_tmp,sample_len,1,1) .* repmat(dop_tmp(:,1,1), 1, obj.Nrx, obj.Ntx);
        end
        
        
        % Cluter 당 채널 계수를 계산하는 함수 ==================================
        function [r_coeff, c_ang, res_ang] = FD_channel(obj, sample_len, i_vel)
            % sample_len: 시간 영역 채널 길이 (송신 신호의 샘플 길이와 동일)
            % i_vel: 각 샘플에 대한 속도 벡터(3차원) e.g. [160 0 0]: x 방향으로 160km/h
            % c_ang: 송수신 각도 c_ang = [ ZoD(1:n_path); AoD(1:n_path); ZoA(1:n_path); AoA(1:n_path); ]
            % ang: c_ang에 대한 subcluster 각도
            
            % 변수 초기화(속도, 파장, 샘플 간격, 안테나 행렬, 첫 번째 경로의 인덱스)
            if nargin < 3, vel = 0; else, vel = i_vel * 5/18; end
            if length(vel) < 3, vel = [vel 0 0]; end
            obj.lamda = (3e8) / obj.fc;
            obj.Ts = 1/obj.fs;
            obj.init_d();
            f_idx = 0;
            
            % 각 path당 평균 전력 및 각도를 계산
            obj.def_pow();
            [res_ang, c_ang] = obj.gen_angle();
            
            % 방사패턴 간섭 변수 계산
            xpr = 10.^( ( randn(obj.n_path, obj.n_mray) * obj.xpr_std + obj.xpr_mu ) / 10 );
            
            % 각 clusster당 채널 계수 계산
            coeff = zeros(obj.n_path+1, sample_len, obj.Nrx, obj.Ntx);
            for i = 1:obj.n_path
                
                % 0 평균전력이 할당된 경로를 계산 제외 및 첫 경로 index 저장
                if obj.pdp(i) == 0, continue; 
                elseif f_idx == 0, f_idx = i;   end
                
                % 각 ray당 채널 계수 계산
                tmp_coeff = zeros(sample_len, obj.Nrx, obj.Ntx);
                for j = 1:obj.n_ray(i)
                    ang = res_ang{i};
                    sub_tmp = obj.ray_cal(sample_len, ang(1,j), ang(2,j), ang(3,j), ang(4,j), xpr(i,j), vel);
                    sub_tmp = sub_tmp * obj.pas(ang, j);
                    tmp_coeff = tmp_coeff + sub_tmp;
                end
                
                % 각 cluster에 계수 할당
                coeff(i,:,:,:) = tmp_coeff * sqrt(obj.pdp(i));
            end
            
            % LOS 계수 생성
            if (obj.los & obj.los_flag) == 1
                Kr = 10^(obj.K/10);
                coeff = sqrt( 1 / (Kr + 1) ) * coeff;
                nlos_tmp = zeros(sample_len, obj.Nrx, obj.Ntx);
                nlos_tmp(:,:,:) = coeff(f_idx,:,:,:);
                coeff_los = obj.ray_cal(sample_len, obj.ZoD_L, obj.AoD_L, obj.ZoA_L, obj.AoA_L, 0, vel);
                coeff(f_idx,:,:,:) = nlos_tmp  +  sqrt( Kr / (Kr + 1) ) * coeff_los;
            end
            
            % 상대거리를 반영
            p_loss = -10 * obj.exp_beta * log10(obj.distance_rate);
            shadowing = randn(1) * obj.sdw_std;
            loss = 10^( (p_loss + shadowing) / 10 );
            coeff = coeff * sqrt(loss);
            
            % 출력값 저장
            r_coeff = coeff(1:obj.n_path,:,:,:);
        end
        
        
        % 채널 계수를 이용하여 수신 신호를 계산하는 함수 =====================
        function [rx_sig] = FD_fading(obj, sig, coeff)
            
            % 매개변수 초기화
            [tap_len, sym_len, N_rx, N_tx] = size(coeff);
            
            % 송신 신호에 채널 계수 적용
            temp = zeros(tap_len, sym_len, N_rx);
            for i = 1:N_rx
                for j = 1:N_tx
                    % 수신 안테나마다 채널과 송신 신호 내적
                    temp(:,:,i) = temp(:,:,i) + coeff(:,:,i,j) .* ( ones(tap_len,1) * sig(j,:) ) ;
                end
            end
            
            % 다중 경로 적용
            rx_sig = zeros(N_rx, sym_len + tap_len -1);
            for m = 1:N_rx
                % 다중 경로 배열 생성
                flat_m = zeros(tap_len, sym_len + tap_len -1);
                
                for i = 1:tap_len
                    flat_m(i, i:i + sym_len - 1) = temp(i,:,m);
                end
                
                % 다중 경로 중첩
                rx_sig(m,:) = sum( flat_m, 1 );
            end
        end
        
        % 주어진 지연시간 및 평균전력을 통해 시스템에 맞는 PDP를 계산하는 함수
        function [] = pdp_interp(obj, delay, power)
            % Delay [sec]
            % power [Watt]
            
            % 길이가 다를 경우 종료
            if length(delay) ~= length(power)
                disp( 'The sizes of delay and power doesn not match ')
                return
            end
            
            % PDP 벡터 생성
            ts = 1/obj.fs;
            
            % index 시작 위치 및 다음 계수로의 전력 분산으로 인한 길이 연장 '2'
            len = ceil( max(delay) / ts ) + 2;
            obj.pdp = zeros(1, len);
            
            % 올림하여 위치 계산
            coef = floor( delay / ts);
            relative_d = abs(delay / ts - coef);
            p0 = (1-relative_d) .* power;
            p1 = relative_d .* power;
            
            % Power 값을 계산하여 저장
            for i = 1:length(delay)
                idx = coef(i)+1;
                obj.pdp( idx ) = obj.pdp( idx ) + p0(i);
                obj.pdp( idx+1) = obj.pdp( idx+1 ) + p1(i) ;
            end
            
            % 정규화 수행
            obj.pdp = obj.pdp / sum(obj.pdp);
            
        end
        
        % 거리 및 송신 전력을 기반으로 신호의 수신 SNR을 계산하는 함수 ========
        function [snr] = path_loss(obj, tx_psd, bandwidth, distance)
            % tx_psd: 전송 신호의 평균 PSD(Power Spectral Density) [dB/Hz]
            % bandwith: 전송 신호의 대역폭
            
            % 변수 초기화
            if nargin < 4
                distance  =  sqrt( sum( (obj.p_src - obj.p_dst).^2 ) );
            end
            
            % 송신, 잡음 전력 및 path loss 계산
            tx_power = 10^(tx_psd/10) * bandwidth;
            N_power = 10^(obj.No/10) * bandwidth;
            p_loss = -20 .* log10( 4*pi / obj.lamda ) - 10 .* obj.exp_beta .* log10( distance ) - obj.L + obj.Gt + obj.Gr;
            
            % Shadowing 현상을 반영하여 SNR을 계산
            shadowing = randn(1) * obj.sdw_std;
            loss = 10^( (p_loss + shadowing) / 10 );
            rx_power = tx_power * loss;
            snr = 10*log10(rx_power / N_power);
        end
        
        
    end
end
