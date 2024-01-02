# det-fastfold-inference
Run FastFold inference uing HPE Machine Learning Development Environment (aka MLDE)

Advantages of running training/inference processes on MLDE:

- **Simplified environment setting**: Set up a shell config file shell.yaml that provides a readily built docker image by Determined AI (aka MLDE) and available on DockerHub. These docker images are frequently released and users just need to pick and choose the right image which, in this example, requires CUDA 11.3 and Pytorch >= 1.12.

- **Containerised environment**: Process environment is isolated from the host OS, so users do have constraint with upgrading/downgrading packages

- **Automated GPU resource procurement** by only defining slots number in a config file

- **Automated SSH** to the launched shell environment without the need to manually setup and manage credentials when connecting to a remote cluster

# References: 
1. [FastFold github repo](https://github.com/hpcaitech/FastFold/tree/main)
2. [How to start a shell in MLDE](https://hpe-mlde.determined.ai/latest/tools/cli/commands-and-shells.html#shells)

# Method
## Step 1: Launch a MDLE shell
### 1.1 Start a MLDE shell. 

```yaml
description: fastfold-inference
environment:
  image: determinedai/environments:cuda-11.3-pytorch-1.12-gpu-mpi-0.26.4
  environment_variables:
    - NCCL_DEBUG=INFO
    - PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000
    # You need to set PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000 to inference such an extreme long sequence.
    # You may need to modify this to match your network configuration.
    - NCCL_SOCKET_IFNAME=ens,eth,ib
    - CUDA_LAUNCH_BLOCKING=1
resources:
  slots: 8
  resource_pool: A100
```

Note: Users can define an environment variable inside shell.yaml, ex., "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000" which is used to inference extremely long sequences.

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

Note: Step 2 will be simplified in future release.

## Step 3: Run inference
### 3.1 Edit the inference.sh file

```bash
# add '--gpus [N]' to use N gpus for inference
# add '--enable_workflow' to use parallel workflow for data processing
# add '--use_precomputed_alignments [path_to_alignments]' to use precomputed msa
# add '--chunk_size [N]' to use chunk to reduce peak memory
# add '--inplace' to use inplace to save memory

python inference.py /PATH/TO/fastfold/data/fasta_dir/5005.fasta /PATH/TO/openfold/data/pdb_mmcif/data/files \
    --output_dir /PATH/TO/fastfold/outputs \
    --gpus 8 \
    --uniref90_database_path /PATH/TO/openfold/data/uniref90/uniref90.fasta \
    --mgnify_database_path /PATH/TO/openfold/data/mgnify/mgy_clusters_2018_12.fa \
    --pdb70_database_path /PATH/TO/openfold/data/pdb70/pdb70 \
    --uniref30_database_path /PATH/TO/openfold/data/uniref30/UniRef30_2021_03 \
    --bfd_database_path /PATH/TO/openfold/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --jackhmmer_binary_path `which jackhmmer` \
    --hhblits_binary_path `which hhblits` \
    --hhsearch_binary_path `which hhsearch` \
    --kalign_binary_path `which kalign` \
    --enable_workflow \
    --param_path /PATH/TO/fastfold/data/params/params_model_1_ptm.npz \
    --use_precomputed_alignments /PATH/TO/fastfold/outputs/alignments \
    --chunk_size 32 \
    --inplace
```

### 3.2 Run inference
```shell
bash inference.sh arg1 arg2 arg3
```
arg1: # of residues in fasta file
arg2: # of GPUs
arg3: chunk size

![](/assets/gpu_util_5005.png)

## Notes: 
### Pytorch cuda memory allocation

Set `PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000` to inference long sequence, ex., 8K or 10K residues

### Chunk size effect
Reducing to a smaller chunk_size to reduce memory peak and OOM.
See example below on how different chunk_sizes work/lead to OOM when running a 3507-residue input.

- Chunk_size 512
RuntimeError: CUDA out of memory. Tried to allocate 93.89 GiB (GPU 0; 79.21 GiB total capacity; 26.53 GiB already allocated; 48.67 GiB free; 28.83 GiB reserved in total by PyTorch) If reserved memory is >> allocated memory try setting max_split_size_mb to avoid fragmentation.  See documentation for Memory Management and PYTORCH_CUDA_ALLOC_CONF

- Chunk_size 256
RuntimeError: CUDA out of memory. Tried to allocate 46.95 GiB (GPU 1; 79.21 GiB total capacity; 25.04 GiB already allocated; 45.61 GiB free; 31.77 GiB reserved in total by PyTorch) If reserved memory is >> allocated memory try setting max_split_size_mb to avoid fragmentation.  See documentation for Memory Management and PYTORCH_CUDA_ALLOC_CONF

- Chunk_size 128
Both GPUs use about almost ~80GB, but might still be running okay. 
