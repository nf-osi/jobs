## Metadata Report (WIP)

This job/service is for regularly scanning file metadata to review the state of annotations and create a report. 
There are several important ideas/questions that this will try to tackle:

- The main portal fileview gives a fiew only on the core subset of annotations, what's minimally required. 
It DOES NOT provide a comprehensive view of annotations, including a lot of past "legacy" annotations.
For the present, we may also want to see what is "average" vs. "above average" when people go above and beyond to add what's _not_ required.
This requires examining all annotations via an improved crawler implementation. 
This helps to better understand the state of metadata in the past, present, and potentially the future evolution (e.g. if we see new annotations used outside of the data model). 

- What percent of metadata are complete / correct? Can we use this to see how the quality of metadata has changed over time? Though imperfect, these report records might provide an additional reference. 

