clc;
clear;
obj = VideoReader('F:\sm_avis_nofuzzy\pimg.avi');
totalFrames = obj.NumberOfFrames;
DIRIMG = 'F:\sm_imgs\';
DIRAVI = 'F:\sm_avis\';
delete(strcat(DIRIMG,'*.bmp'));
%cntFrames = 23;
%获取视频帧
for k = 1 : totalFrames
    frame = read(obj,k);
    imwrite(frame,strcat(DIRIMG, num2str(k),'.bmp'),'bmp');
end
% 获取每一帧的向量值
T = 2.5; %偏差阈值
alpha = 0.005; %学习率
thresh = 0.3; %前景阈值
sd_init = 6; % 初始化标准差
d = 1;
C = 3; % C个components
K = 3; % fuzzy 模型的系数

I = imread(strcat(DIRIMG, '1.bmp'));
fr_bw = I;
[row, col] = size(fr_bw);
col = col/3;
fg_pre = zeros(row, col);  % 前景矩阵
bg = zeros(row, col);  % 背景矩阵
n = 10^6;
[X,label,model] = mixGaussRnd(d,C,n); 
w = zeros(row, col, C);
mu = zeros(row, col, C);
sigma = zeros(row, col, C);
u_diff = zeros(row, col, C); % 像素与某个高斯模型均值的绝对距离
p = alpha/(1/C); % 初始化p向量，用来更新均值和标准差
rank = zeros(1,C); % 各个高斯分布的优先级
pixel_depth = 8; % 每个像素8bit
pixel_range = 2^pixel_depth - 1; %像素值范围[0,255]

for k=1:C
    w(:,:,k) = model.w(k)
    mu(:,:,k) = model.mu(k);
    Sigma = reshape(model.Sigma,1,3);
    sigma(:,:,k) = Sigma(k);
end
for n=1:totalFrames
    frame = strcat(DIRIMG, num2str(n), '.bmp');
    I1 = imread(frame);
    img = rgb2gray(I1);
    fr_bw = I1;
    % 计算新像素与第m个高斯模型均值的绝对距离
    for m=1:C
        u_diff(:,:,m) = abs(double(fr_bw(:,:,m)) - double(mu(:,:,m)));
    end
    for i=1:row
        for j=1:col
            flag = 0;
            for k=1:C
                %引入fuzzy模型
                muup(i,j,k) = mu(i,j,k) + K*sigma(i,j,k);
                mulow(i,j,k) = mu(i,j,k) - K*sigma(i,j,k);
                if(img(i,j) < mulow(i,j,k))
                    mu(i,j,k) = mulow(i,j,k);
                elseif(img(i,j) > muup(i,j,k))
                    mu(i,j,k) = muup(i,j,k);
                else
                    mu(i,j,k) = mu(i,j,k);
                end
                if(abs(u_diff(i,j,k)) <= T*sigma(i,j,k))
                    flag = 1;
                    %更新权重、均值、标准差、p
                    w(i,j,k) = (1-alpha)*w(i,j,k) + alpha*flag;
                    p = alpha/w(i,j,k);
                    mu(i,j,k) = (1-p)*mu(i,j,k) + p*double(fr_bw(i,j));
                    sigma(i,j,k) = sqrt((1-p)*(sigma(i,j,k)^2) + p*((double(fr_bw(i,j)) - mu(i,j,k)))^2);
                else
                    w(i,j,k) = (1 - alpha)*w(i,j,k);
                end
            end
            bg(i,j) = 0;
            for k=1:C
                bg(i,j) = bg(i,j) + mu(i,j,k)*w(i,j,k);
            end
            % 没有与像素值匹配的模型，则创建新的模型
            if(flag == 0)
                [min_w, min_w_index] = min(w(i,j,:)); % 寻找最小权重值
                mu(i,j,min_w_index) = double(fr_bw(i,j));
                sigma(i,j,min_w_index) = sd_init;
            end
            rank = w(i,j,:)./sigma(i,j,:); % 计算模型优先级
            rank_ind = [1:1:C];
            % 计算前景
            fg_pre(i,j) = 0;
            while((flag == 0) && (k <= C))
                if(abs(u_diff(i,j,rank_ind(k))) <= T*sigma(i,j,rank_ind(k))) %像素与第k个高斯模型匹配
                    fg_pre(i,j) = 0;
                else
                    fg_pre(i,j) = 255;
                end
                k = k+1;
            end
        end
    end
    % 对图像进行形态学处理
    SE1 = strel('disk', 1);
    SE2 = strel('disk', 4);
    %fg = imerode(fg_pre, SE1);
    fg = imdilate(fg_pre, SE1);
    fg = imfill(fg, 'holes');
    fg = imclearborder(fg);
    
    %dFg = imdilate(eFg,SE2);
    %closeFg = imclose(fg_pre, SE2);
    %openFg = imopen(closeFg, SE1);
    imwrite(fg_pre,...
        strcat(DIRIMG, 'fg',...
        num2str(n),'.bmp'),'bmp');
    file=dir(strcat(DIRIMG,'fg',num2str(n),'.bmp'));  
end


obj_gray = VideoWriter(strcat(DIRAVI,'fg_pre.avi'));   %所转换成的视频名称

%将单张图片存在avi文件
open(obj_gray);
for k = 1: totalFrames
    fname = strcat(DIRIMG,'fg',num2str(k),'.bmp');
    frame = imread(fname);
    writeVideo(obj_gray, frame);
end
close(obj_gray);
