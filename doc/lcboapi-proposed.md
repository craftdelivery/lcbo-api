# BevGraph: Proposal for the future of LCBO API

<p align="center">
  <img width="33%" src="https://snappities.s3.amazonaws.com/i0ifq827x65w3vtfgrk6.png" alt="BevGraph">
</p>

I can't stop thinking about this, so I'm just going to get it out in the open so I can stop thinking about it! :laughing: I can see a bigger vision for this API and data, read on and give it a think, also let me know what you think! I need your help :pray:

## Conductor (`bevgraph/conductor`)

Responsible for crawling source data, normalizing, and shipping to trusted
external nodes. This might just be part of the API Server? It orchestrates the crawling process and the post-crawl process of notifying 3rd parties, waiting to hear back, wrapping up all of the data, and applying it to the API.

## 3rd party "data nodes" (external, proprietary)

When a crawl completes, it is packaged into an SQLlite image, and saved to S3. All trusted 3rd party nodes are notified and receive the data package.

Some of these nodes may only consume the data, others might consume it and add value to it in the form of metadata, this could be:

- Additional information (images, geolocation, reviews, etc.)
- Aggregate data (inventory projections)
- Additional retail locations for non-LCBO items
- Craft beer locations and inventory
- Winery locations and inventories
- U.S. stores?
- Winemaking regions and information
- Etc! Etc! Etc!

_If you let your mind wander I'm sure you can think of lots of ideas!_

Trusted nodes use the data as needed and apply metadata, they then also wrap this up in an SQLite image, save to S3 and then notify the conductor. It is important to consider the value structure here, I never considered financials when I started LCBO API and it was the biggest issue, so we need to have that in mind when designing this. Some ideas:

- Charging 3rd party nodes who only consume data direct $$$
- Charging 3rd party nodes who give back data differently
- Consumer API Server charge subscription fee, funds distribute to both LCBO API and the various 3rd party nodes the subscription is active for

The reason we need to charge money is:

- LCBO API: hosting, tipjar for volunteers, to support community programs and charities
- 3rd party: thanks for adding value, here's some support

## Consumer API Server (`bevgraph/server`)

API server (GraphQL, JSON:API, etc.) similar to current Rails app. Takes care of what LCBO API currently does, but taking into consideration new responsibilities:

- Charging consumers subscription fees
- Applying new 3rd party metadata to API design
- Additional models?
- Storage/retrieval of 3rd party aggregations

These are hard problems and I won't try to solve them here, but if anyone wants to work on them with me just open an issue, I'd love to get started :heart:

## Official CLI interface (`@bevgraph/cli`)

An official CLI tool for interacting with the BevGraph API. Would be able to fetch all endpoints and return data in JSON, CSV, whatever makes sense. Would be written in Node.js to ensure maximum accessibility.

```
npm i -g @bevgraph/cli

# Set your API key
bevgraph config:set "api-key" "2YSFD8jhbFGaosf9823u923hwe8f7hq872oq3u4fhadjq7238rerksbfZXMNV"

# Find a product by source ID
# (products will be normalized to UPC but will retain various source IDs as well)
bevgraph product "lcbo/438457" --format="csv" > longslice.csv # Store CSV output in a file
```

Also human-readable output would be available (perhaps even the default, could be changed via config of course)

```bash
bevgraph products --producer="collective arts" --format="human"
```

Might output something like:

```
Found 20 products in 33ms:

--- [0]
  name: "Collective Arts Ransack the Universe IPA"
  upc: "20003492938484"
  source: "lcbo/450312"
  ...
[1]
  ...
```

People could probably do most things using this CLI interface, of course JSON:API and GraphQL APIs would be available for all other uses as well.

:thinking: I'm pretty stoked about this!

## API clients

Here's where I think the different platforms and paradigms can come in! The API server and conductor should probably be Ruby since that's what the project is already using, but I'm not opposed to changing that, let's have the discussion!

Where I think it could be really exciting for diversity of technologies is in API consumer libraries. I think the API server should return JSON:API or GraphQL (or both, ideally!) but the clients to consume that data could be written in whatever languages people want to support.

## Consumer pricing model

- No more API snapshots, if you want that, you have to register as a 3rd party
- Usage-based, reasonable $$
- Free tier: reasonable but low rate limit, access to non-profit 3rd party subscriptions
- Each 3rd party subscription increases cost by $$

## 3rd party pricing model

Third parties that only consume the data should be charged enterprise-level fees, I don't know what those are, business people please help!

Third parties that add metadata but are commercial entities should also perhaps be charged a reasonable maintenance fee. They would also get a cut of consumer subscription fees.

Third parties that are non-profit would not have to pay a fee, and we would give them a cut of consumer subscription fees.

## Additional thoughts

The conductor design I proposed is very synchronous. This was just how I was thinking at the time, it probably makes more sense to allow 3rd party nodes to report back whenever they want. The concept of a Dataset in LCBO API is based on a crawl beginning and ending, that could still be a thing, the concept of a "snapshot" but I feel like people who want that would really want to register as a 3rd party. :thinking: Something to consider.

## Modelling changes

I have lots of ideas here, but ultimately products need to be normalized somehow. UPC, name+producer, etc. Solvable problems for sure, big problems too. The current modelling will not support this. Multiple retail locations from multiple retailers selling the same products at different prices, etc. All of this will have to be considered and accommidated for, and presented in a very straight-forward way to consumers of the API.

## Does this interest you / excite you?

If so, get in touch and let's start discussing it and designing it! Open an [issue](https://github.com/heycarsten/lcbo-api/issues/new), tweet me [@heycarsten](https://twitter.com/heycarsten), or email me: heycarsten@gmail.com :+1:
