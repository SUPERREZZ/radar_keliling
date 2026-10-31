<?php

namespace Tests\Feature;

use Tests\TestCase;

class SwaggerDocsTest extends TestCase
{
    public function test_swagger_ui_is_accessible_in_non_production(): void
    {
        $response = $this->get('/docs');
        $response->assertOk()
            ->assertSee('SwaggerUIBundle')
            ->assertSee('Radar Keliling API');
    }

    public function test_swagger_is_hidden_in_production(): void
    {
        config(['app.env' => 'production']);

        $this->get('/docs')->assertNotFound();
        $this->getJson('/docs/api.json')->assertForbidden();
    }

    public function test_swagger_openapi_json_spec_is_accessible_in_non_production(): void
    {
        $response = $this->getJson('/docs/api.json');
        $response->assertOk()
            ->assertJsonPath('openapi', '3.1.2')
            ->assertJsonStructure([
                'openapi',
                'info' => ['title', 'version'],
                'paths',
            ]);
    }
}

