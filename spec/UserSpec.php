<?php

declare(strict_types=1);

namespace spec\TestProject;

use PhpSpec\ObjectBehavior;
use Prophecy\Argument;

/**
 * {@inheritDoc}
 *
 * @see \TestProject\User
 */
final class UserSpec extends ObjectBehavior
{
    public function let(): void
    {
        $this->beConstructedWith(1, 'Alex');
    }

    public function it_is_initializable(): void
    {
        $this->shouldHaveType('\TestProject\User');
    }

    public function it_should_pass_during_tell_name(): void
    {
        $this->tellName()->shouldReturn('My name is Alex.');
    }

    public function it_should_fail_during_tell_name(): void
    {
        $this->tellName()->shouldReturn('My name is George.');
    }
}
