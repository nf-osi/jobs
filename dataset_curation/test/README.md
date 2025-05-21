## Agentic dataset curation test

### Overview 

Agentic AI can autonomously interact with various resources and use tools to perform research tasks. 
Like people, AI agents can do work most effectively if given clear goals, an optimized guide, and the right tools for the task. 
Here, agents are applied to a dataset curation task, where the agent is given some initial, pre-summarized information and allowed to gather more information and submit results, which are high-quality dataset metadata that conform to a standard schema. 
We can compare this to a non-agentic method of deriving dataset metadata, where a generative model is prompted to generate metadata with the same initial pre-summarized information, but without the ability to make further explorations or decisions. 

Agentic dataset curation is done in a safe environment where the agent has read-only tools like querying tables but not be able to make actual changes; the work is done in the background without human intervention, as opposed to when an agent is accomplishing tasks with interactive human oversight/micromanagement. 
The human reviewer sees the results after the task is done.

### Agent Design

#### Configuration

- Model: Google Gemini Pro-2.5
- Tools:
  - query_table
  - commit_metadata (simulated) 

#### Discussion

From previous assessment of models from different providers, we understand that models used as curation agents require:
- Sufficient intelligence/thinking for understanding the task and processing information.
- Knowing when and how to use tools (function calling); we select models based on our own testing and by using existing benchmark leaderboard data such as [BFCL](https://gorilla.cs.berkeley.edu/leaderboard.html) and others.
- High rate limits, since the agent can make many calls per minute or be interacting with unknown large amounts of data (looking at query results, reading papers) where tokens can easily exceed the input token limits per minute. While these issues can be handled with additional architecture, this adds engineering work and layers of complication not within scope of this test.

From previous assessment, we saw that Google Gemini Pro-2.5 did best while having very cost-effective pricing. 

### Supplement: Comparison to batch processing

- For batch processing, we only need sufficient intelligence and do not need have to worry as much about tool use capability or rate limits.
- Batch curation is a lot cheaper but not as detailed and not as adaptable, compared to the agent that can gather more information than what's provided and potentially provide better results ultimately.
It is a question of marginal improvement vs. the extra agentic curation costs.

