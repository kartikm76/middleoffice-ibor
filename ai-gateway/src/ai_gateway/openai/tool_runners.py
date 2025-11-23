from __future__ import annotations
from abc import ABC, abstractmethod
from datetime import date
from ai_gateway.agents.analyst import AnalystAnswer, AnalystAgent
from ai_gateway.openai.routing_models import ToolDecision

class ToolRunner(ABC):
    """ Base class for a routed tool call"""

    @abstractmethod
    def run(self, decision: ToolDecision, question: str) -> AnalystAnswer:
        """ Execute the appropriate AnalystAgent method given the ToolDecision.
        Implementations must:
        - Validate required fields in decision
        - Convert strings → date where needed
        - Set ans.question = original natural-language question
        """
        raise NotImplementedError

class PositionsRunner(ToolRunner):
    def __init__(self, analyst_agent: AnalystAgent) -> None:
        self.analyst_agent = analyst_agent

    def run(self, decision: ToolDecision, question: str) -> AnalystAnswer:
        portfolio_code = decision.get("portfolioCode")
        as_of = decision.get("asOf")

        if not portfolio_code or not as_of:
            raise ValueError("Missing required fields in ToolDecision for positions")

        as_of_dt = date.fromisoformat(as_of)

        answer = self.analyst_agent.positions_today(
            portfolio_code = portfolio_code,
            as_of = as_of_dt,
        )
        answer.question = question
        return answer

class TradesRunner(ToolRunner):
    def __init__(self, analyst_agent: AnalystAgent) -> None:
        self.analyst_agent = analyst_agent

    def run(self, decision: ToolDecision, question: str) -> AnalystAnswer:
        portfolio_code = decision.get("portfolioCode")
        instrument_code = decision.get("instrumentCode")
        as_of = decision.get("asOf")

        if not portfolio_code or not instrument_code or not as_of:
            raise ValueError("Missing required fields in ToolDecision for trades")

        as_of_dt = date.fromisoformat(as_of)

        answer = self.analyst_agent.show_trades(
            portfolio_code = portfolio_code,
            instrument_code = instrument_code,
            as_of = as_of_dt,
        )
        answer.question = question
        return answer

class PnLRunner(ToolRunner):
    def __init__(self, analyst_agent: AnalystAgent) -> None:
        self.analyst_agent = analyst_agent

    def run(self, decision: ToolDecision, question: str) -> AnalystAnswer:
        portfolio_code = decision.get("portfolioCode")
        instrument_code = decision.get("instrumentCode")
        as_of = decision.get("asOf")
        prior = decision.get("prior")

        if not portfolio_code or not as_of or not prior:
            raise ValueError("Missing required fields in ToolDecision for pnl")

        as_of_dt = date.fromisoformat(as_of)
        prior_dt = date.fromisoformat(prior)

        answer = self.analyst_agent.why_pnl_changed(
            portfolio_code = portfolio_code,
            instrument_code = instrument_code,
            as_of = as_of_dt,
            prior = prior_dt,
        )
        answer.question = question
        return answer

class PricesRunner(ToolRunner):
    def __init__(self, analyst_agent: AnalystAgent) -> None:
        self.analyst_agent = analyst_agent

    def run(self, decision: ToolDecision, question: str) -> AnalystAnswer:
        instrument_code = decision.get("instrumentCode")
        from_date = decision.get("fromDate")
        to_date = decision.get("toDate")

        if not instrument_code or not from_date or not to_date:
            raise ValueError("Missing required fields in ToolDecision for prices")

        from_date_dt = date.fromisoformat(from_date)
        to_date_dt = date.fromisoformat(to_date)

        answer = self.analyst_agent.prices(
            instrument_code=instrument_code,
            from_date=from_date_dt,
            to_date=to_date_dt,
        )
        answer.question = question
        return answer


# Backwards-compatible alias for IDE/static analyzers that expect PnlRunner
PnlRunner = PnLRunner
