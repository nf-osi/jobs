## Agentic dataset curation test

### Overview 

Agentic AI can autonomously interact with various resources and use tools to perform research tasks. Here, agents are tested on dataset curation as a similar type task, where the agent is given some initial, pre-summarized information and allowed to decide and act on gathering more information about a project and its datasets using tools at hand with the goal of creating high-quality dataset metadata that conform to a standard schema. This is compared to a non-agentic method of deriving dataset metadata, where a generative models are prompted to generate metadata with the same initial pre-summarized information, without the ability to make further explorations or decisions.  

To test agentic dataset curation safely, a **semi-sandboxed environment** is set up so that an agent can go through a batch of projects and datasets in the background without human intervention. The agent is free to use read-only tools with live tables, such as query tables, read wikis, and pull profile names. However **write functions (committing metadata) is simulated**. 
The semi-sandboxing acts as a guardrail for this experiment. Note that this is different from when an agent is accomplishing tasks with interactive human oversight, where an agent can make changes with human approval.

These experiments and tests can tell us: 
- Assess a workflow alternative (semi-sandboxing and secondary analysis) to use as a more scalable guardrail, instead of using interactive human administration/micromanagement for every commit as a guardrail, which would be too labor-intensive and less scalable.
- Learn which AI model, from different providers, may be best suited for different modes of metadata curation.
- Learn how behaviors correlate with performance (e.g. "this particular sequence of tool use led to the best metadata") for later optimizations (as new prompts) if needed.

### Design

Pre-assessment of models for agentic curation suggest that it requires models with:
- Sufficient intelligence level for understanding curation task and processing information.
- Good benchmarks for knowing when and how to use tools, since exploration requires an agent able and willing to use tools. For exampple, there's data showing that o3-mini is supposedly able but less willing to use tools.
- High rate limits, since the agent can make many calls per minute or be interacting with unknown large amounts of data (looking at query results, reading papers) where tokens easily exceed the input token limits per minute. While these issues can be handled with additional architecture, this adds engineering work and layers of complication not within scope of this test.

For batch processing, we only need sufficient intelligence and do not need have to worry about tool use capability or rate limits.

Questions and assumptions:
- Batch curation should be a lot cheaper but not as detailed and *not as adaptible to projects outside of NF*. Conversly, with agentic curation, the agent should be able to gather more information than what's provided and potentially provide better dataset metadata. The question is if there is marginal improvement worth the extra agentic curation costs. The below comparisons aim to answer this question and others. The comparison **A-gpt-4o** vs **B-gpt-4o** tell us if there is significant marginal benefit to the agentic approach compared compared to the non-agentic approach. The comparison **B-gpt-4o** vs **B-sonnet-3.7** tell us which provider model is better given that we are likely to use batch processing for cost-effectiveness.

#### Comparisons

##### For NF Datasets

- **A for agentic**. Agentic curation is the scenario where AI can autonomously and adaptively interact with project to derive dataset metadata. The agent is given the same information given in the batch condition, but unlike batch condition, the agent has the opportunity to go beyond -- to make decisions and take actions to gather more information.
   - **A-gpt-4o**. Why: GPT-4o is a high-intelligence model with a high rate limit that allows for agentic curation on a large scale.

- **B for batch**. Batch/non-agentic curation (use batch API with given project and pre-summarized dataset info) across 2 models
   - **B-gpt-4o**. Why: GPT-4o is known as a high-intelligence model, and we want to compare non-agentic GPT-4o with agentic GPT-4o to understand the differences.
   - **B-claude-sonnet-3.7**. Why: Claude-Sonnet-3.7 is a high-intelligence model but has a low rate limit that precludes usage for agentic curation currently without more engineering, but it would be useful to compare with GPT-4o in the batch scenario for practical purposes. 

### Setup and evaluation

The projects are split up into batches of ~15 projects, balanced by project size (number of datasets) so that all groups see a variety of projects, big and small. 

#### For batch

- Batch datasets were prepared and results obtained from the respective provider APIs (OpenAI for gpt-4-o and Anthropic for Claude-Sonnet-3.7).
- Metadata was extracted from the model responses and validated according to the schema. 

#### For agentic

- Agents were run in a semi-sandboxed environment where the agent was prompted to do curation with a prompt as close as possible to the batch case.

#### Evaluation 

- Data managers acted as human evaluators to score the metadata without knowing which model or agentic/batch approach. 

#### Dataset metadata evaluation

See issue #99.

### Thoughts on the final workflow

It's very likely that we will use batch curation automatically on a newly released project. *Depending on whether agentic curation is actually better*, we will send in an agent only for problematic projects that need a more adaptable approach (i.e. data managers are displeased with the results from the batch job). 

### Prep batches

- `prep.R`: We retrieve datasets across projects with dataStatus "Available" and "Partially Available" and create design that sets up dataset curation batches with different AI models.
  - "Rolling Release" was excluded because it refers to JHU Biobank, which is special/complicated and already has manually curated datasets
  - There are two projects with data status "Available" excluded because currently no real datasets given that "data" present is only publication-type figures
  - Batches were set up so that all AI models see the same variety of projects (e.g. projects with only 1 dataset vs many dataset)
- `design.csv` output represents the final, reasonably balanced assignments

### Run batches

#### Prerequisites
- Clojure CLI tools installed
- Access to required API keys for AI models (Anthropic and OpenAI)

#### Setup

1. Clone the repository:
```
git clone https://github.com/nf-osi/jobs.git
```
2. Navigate to the project directory:
```
cd jobs/agentic_dataset_curation/test
```

3. Here are the required input and output directory and files you should see:

- Input JSON files in the `input/` directory (A.json, B.json, C.json)
- Schema file at `input/PortalDataset.json`
- `runs/` directory exists for log output

#### Running the process

You can run the dataset curation process using the Clojure CLI. The tool supports different batches (A, B, C) that use different AI agents and input data.

##### Basic Usage

To run a specific batch, for example:
```
clj -X curate-datasets/run-batch! :batch-id A
```

Replace `A` with `B` or `C` to run different batches (see also #Configuration for more details).

##### Output

- Process each dataset in the specified batch
- Simulate committing the metadata (in test mode)
- Log the process to runs/batch-[A|B|C].log

##### Configuration

You can modify the run-config map in curate_datasets.clj to change:

- Input data paths
- AI agents used for each batch

##### Notes

- In the current implementation, commits are simulated using `simulated-wrap-commit`
- The tool uses the `accent` library for AI agent interactions
- Logging is handled by `mulog`
- Refer to the main source code in `curate_datasets.clj` for more details

### Analyze batch results

See `../analysis` directory.
