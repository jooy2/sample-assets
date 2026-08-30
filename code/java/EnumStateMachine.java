// An enum with fields, an abstract method per constant, and a transition
// table that keeps the state machine honest.

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

public class EnumStateMachine {

    enum TicketState {
        OPEN("open") {
            @Override
            Set<TicketState> allowedNext() {
                return EnumSet.of(PENDING, ESCALATED, RESOLVED);
            }
        },
        PENDING("waiting on the customer") {
            @Override
            Set<TicketState> allowedNext() {
                return EnumSet.of(OPEN, RESOLVED, ESCALATED);
            }
        },
        ESCALATED("with a specialist") {
            @Override
            Set<TicketState> allowedNext() {
                return EnumSet.of(RESOLVED);
            }
        },
        RESOLVED("resolved") {
            @Override
            Set<TicketState> allowedNext() {
                return EnumSet.of(CLOSED, OPEN);
            }
        },
        CLOSED("closed for good") {
            @Override
            Set<TicketState> allowedNext() {
                return EnumSet.noneOf(TicketState.class);
            }
        };

        private final String description;

        TicketState(String description) {
            this.description = description;
        }

        abstract Set<TicketState> allowedNext();

        String description() {
            return description;
        }

        boolean canMoveTo(TicketState next) {
            return allowedNext().contains(next);
        }
    }

    static final class Ticket {
        private TicketState state = TicketState.OPEN;
        private final StringBuilder history = new StringBuilder("OPEN");

        void moveTo(TicketState next) {
            if (!state.canMoveTo(next)) {
                throw new IllegalStateException(state + " cannot move to " + next);
            }
            state = next;
            history.append(" -> ").append(next);
        }

        TicketState state() {
            return state;
        }

        String history() {
            return history.toString();
        }
    }

    public static void main(String[] args) {
        for (TicketState state : TicketState.values()) {
            System.out.printf("%-10s %-24s next: %s%n",
                    state, state.description(), state.allowedNext());
        }

        Ticket ticket = new Ticket();
        for (TicketState next : List.of(TicketState.PENDING, TicketState.RESOLVED, TicketState.CLOSED)) {
            ticket.moveTo(next);
        }
        System.out.println("\n" + ticket.history() + " (now " + ticket.state() + ")");

        try {
            ticket.moveTo(TicketState.OPEN);
        } catch (IllegalStateException error) {
            System.out.println("rejected: " + error.getMessage());
        }
    }
}
