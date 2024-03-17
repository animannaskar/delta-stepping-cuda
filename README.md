<body style="font-family: Arial, sans-serif; background-color: #f0f0f0;">
    <header style="background-color: #4CAF50; color: white; padding: 10px 0; text-align: center;">
        <h1 style="font-size: 20px; margin-bottom: 20px;">Parallel implementation of Δ-Stepping on GPUs using CUDA</h1>
    </header>
    <p style="text-align: justify; padding: 20px;">
    This project features a parallel implementation of Δ-Stepping algorithm on NVIDIA GPUs using CUDA (Compute Unified Device Architecture). 
    </p>
    <div style="font-family: Arial, sans-serif; font-size: 16px; line-height: 1.5; text-align: justify; padding: 20px;">
    <p><strong>Parallel delta stepping algorithm proceeds as follows:</strong></p>
    <p><strong>Initialize Buckets:</strong> Start by creating buckets, which are arrays that group nodes based on thier distance from source. For instance, bucket 0 contains nodes with tentative distances from the source node within the range [0, delta).</p>
    <p><strong>Place Source Node:</strong> Put the source node into bucket 0.</p>
    <p><strong>Iterative Process:</strong></p>
    <ul style="list-style-type: disc; margin-left: 20px;">
        <li><strong>Remove and Relax:</strong> Parallelly remove nodes from a bucket and relax their outgoing edges. Relaxing an edge means reducing the tentative distance of the neighbouring vertex if a shorter path exists through the edge.</li>
        <li><strong>Update Buckets:</strong> If an edge relaxation leads to a shorter distance for a node, calculate the new distance and place the node into the bucket corresponding to the new distance.</li>
        <li><strong>Atomic Insertion:</strong> Inserting nodes into buckets is done atomically, ensuring smooth processing without conflicts.</li>
        <li><strong>Repeat Iteration:</strong> Repeat the above process iteratively until all buckets are empty.</li>
    </ul>
    <p>By following these steps, delta stepping efficiently computes shortest paths in the graph by organizing nodes into buckets and parallely processing buckets.</p>
    </div>
    <p>
    <b>Benchmarking results</b>
    <img src = "https://github.com/animannaskar/delta-stepping-sssp-cuda/assets/143376315/46a2a35e-1a7b-497e-9f1d-de22d199296c">
    </p>
</body>
