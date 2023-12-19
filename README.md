# det-fastfold-inference
Run FastFold inference on MLDE

# Ref: 
1. fastfold github repo: https://github.com/hpcaitech/FastFold/tree/main

# Method
## Step 1: Launch a MDLE shell
### 1.1 Start a shell. 
Refer to [How to start a shell in MLDE] (https://hpe-mlde.determined.ai/latest/tools/cli/commands-and-shells.html#shells)

Set up a shell config file shell.yaml that provides a readily built docker image by Determined AI and available on DockerHub

```yaml
description: fastfold-inference
environment:
  image: determinedai/environments:cuda-11.3-pytorch-1.12-gpu-mpi-0.26.4
  environment_variables:
    - NCCL_DEBUG=INFO
    - PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000
    # You need to set PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000 to inference such an extreme long sequence.
    # You may need to modify this to match your network configuration.
    #- NCCL_SOCKET_IFNAME=ens,eth,ib
resources:
  slots: 8
  resource_pool: A100
```

```bash
det -m http://mlds-determined.us.rdlabs.hpecorp.net:8080/ shell start --config-file shell.yaml -c .
```

```
Preparing files to send to master... 2.7MB and 225 files  
Launched shell (id: XXXXXXXX-252b-4071-83a3-830336a3e870).
shell (id: XXXXXXXX-252b-4071-83a3-830336a3e870) is ready.                      
Warning: Permanently added 'XXXXXXXX-252b-4071-83a3-830336a3e870' (RSA) to the list of known hosts.
root@cmd-XXXXXXXX-252b-4071-83a3-830336a3e870-0-9a449ddb-252b-4071-8:~#
```

### 1.2 Open an existing MLDE shell 
```bash
det -m http://mlds-determined.us.rdlabs.hpecorp.net:8080/ shell open <shell_ID>
```

```
shell (id: XXXXXXXX-252b-4071-83a3-830336a3e870) is ready.                      
Last login: Tue Dec 19 02:42:39 2023 from 10.42.3.76
(base) root@cmd-XXXXXXXX-252b-4071-83a3-830336a3e870-0-9a449ddb-252b-4071-8:~#
```

## Step 2: Setup environment 
```bash
apt update 
cd /run/determined/workdir
conda env create --name=fastfold -f environment.yml
conda init
exit 
```

Then reopen the shell using the step 1.2

```bash
conda activate fastfold
python setup.py install
```

## Step 3: Run inference
### 3.1 Edit the inference.sh file

```bash
# add '--gpus [N]' to use N gpus for inference
# add '--enable_workflow' to use parallel workflow for data processing
# add '--use_precomputed_alignments [path_to_alignments]' to use precomputed msa
# add '--chunk_size [N]' to use chunk to reduce peak memory
# add '--inplace' to use inplace to save memory

python inference.py /$PATH/fastfold/data/fasta_dir/5005.fasta /$PATH/openfold/data/pdb_mmcif/data/files \
    --output_dir /$PATH/fastfold/outputs \
    --gpus 8 \
    --uniref90_database_path /$PATH/openfold/data/uniref90/uniref90.fasta \
    --mgnify_database_path /$PATH/openfold/data/mgnify/mgy_clusters_2018_12.fa \
    --pdb70_database_path /$PATH/openfold/data/pdb70/pdb70 \
    --uniref30_database_path /$PATH/openfold/data/uniref30/UniRef30_2021_03 \
    --bfd_database_path /$PATH/openfold/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --jackhmmer_binary_path `which jackhmmer` \
    --hhblits_binary_path `which hhblits` \
    --hhsearch_binary_path `which hhsearch` \
    --kalign_binary_path `which kalign` \
    --enable_workflow \
    --param_path /$PATH/fastfold/data/params/params_model_1_ptm.npz \
    --use_precomputed_alignments /$PATH/fastfold/outputs/alignments \
    --chunk_size 32 \
    --inplace
```
Replace $PATH with an actual path.

```shell
bash inference.sh
```

![](/assets/gpu_util_5005.png)

## Notes: 
### Pytorch cuda memory allocation

Set `PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000` to inference long sequence, ex., 8K or 10K residues

### Chunk size effect
Adjusting to a smaller chunk_size to reduce memory peak and OOM.
See example below on how different chunk_sizes work/lead to OOM when running a 3507 sequence input.

- Chunk_size 512
RuntimeError: CUDA out of memory. Tried to allocate 93.89 GiB (GPU 0; 79.21 GiB total capacity; 26.53 GiB already allocated; 48.67 GiB free; 28.83 GiB reserved in total by PyTorch) If reserved memory is >> allocated memory try setting max_split_size_mb to avoid fragmentation.  See documentation for Memory Management and PYTORCH_CUDA_ALLOC_CONF

- Chunk_size 256
RuntimeError: CUDA out of memory. Tried to allocate 46.95 GiB (GPU 1; 79.21 GiB total capacity; 25.04 GiB already allocated; 45.61 GiB free; 31.77 GiB reserved in total by PyTorch) If reserved memory is >> allocated memory try setting max_split_size_mb to avoid fragmentation.  See documentation for Memory Management and PYTORCH_CUDA_ALLOC_CONF

- Chunk_size 128
Both GPUs use about almost ~80GB, but might still be running okay. 
