# add '--gpus [N]' to use N gpus for inference
# add '--enable_workflow' to use parallel workflow for data processing
# add '--use_precomputed_alignments [path_to_alignments]' to use precomputed msa
# add '--chunk_size [N]' to use chunk to reduce peak memory
# add '--inplace' to use inplace to save memory

python inference.py /nvmefs1/daniel.cao/fastfold/data/fasta_dir/$1.fasta /nvmefs1/daniel.cao/openfold/data/pdb_mmcif/data/files \
    --output_dir /nvmefs1/daniel.cao/fastfold/outputs \
    --gpus $2 \
    --uniref90_database_path /nvmefs1/daniel.cao/openfold/data/uniref90/uniref90.fasta \
    --mgnify_database_path /nvmefs1/daniel.cao/openfold/data/mgnify/mgy_clusters_2018_12.fa \
    --pdb70_database_path /nvmefs1/daniel.cao/openfold/data/pdb70/pdb70 \
    --uniref30_database_path /nvmefs1/daniel.cao/openfold/data/uniref30/UniRef30_2021_03 \
    --bfd_database_path /nvmefs1/daniel.cao/openfold/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --jackhmmer_binary_path `which jackhmmer` \
    --hhblits_binary_path `which hhblits` \
    --hhsearch_binary_path `which hhsearch` \
    --kalign_binary_path `which kalign` \
    --enable_workflow \
    --param_path /nvmefs1/daniel.cao/fastfold/data/params/params_model_1_ptm.npz \
    --use_precomputed_alignments /nvmefs1/daniel.cao/fastfold/outputs/alignments \
    --chunk_size $3 \
    --inplace